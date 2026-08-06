package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// normalizeLegacyHandlerOp repairs the small set of whole-class shapes emitted by
// older hosted models. The public contract remains the split Handler ops; this
// compatibility path only accepts deterministic translations and rejects opaque
// code instead of guessing.
func normalizeLegacyHandlerOp(item map[string]json.RawMessage, includeMethods, hasLegacyClassCode, legacyMethodsNeedClassMethods bool, existingMethods map[string]struct{}) ([]json.RawMessage, error) {
	if _, ok := item["op"]; !ok {
		// Keep the older `kind:"set_method"` update alias on the existing
		// update_method normalizer below; this compatibility path is for create
		// payloads whose discriminator is `type` or a legacy `op` value.
		return nil, nil
	}
	op := handlerOpName(item)

	switch op {
	case "set_code":
		return normalizeLegacySetCode(item, includeMethods)
	case "set_methods":
		return normalizeLegacySetMethods(item, legacyMethodsNeedClassMethods, existingMethods)
	case "set_init_args":
		return normalizeLegacySetInitArgs(item)
	case "set_method":
		return normalizeLegacySetMethod(item, hasLegacyClassCode)
	case "declare_method":
		return normalizeLegacyDeclareMethod(item, hasLegacyClassCode)
	case "set_method_inputs":
		return normalizeLegacyMethodFields(item, "inputs", "parameters")
	case "set_method_outputs":
		return normalizeLegacyMethodFields(item, "outputs", "outputs")
	default:
		return nil, nil
	}
}

func handlerOpName(item map[string]json.RawMessage) string {
	for _, key := range []string{"op", "type", "kind"} {
		var value string
		if err := json.Unmarshal(item[key], &value); err == nil {
			return value
		}
	}
	return ""
}

func canonicalizeLegacyDiscriminator(item map[string]json.RawMessage) map[string]json.RawMessage {
	if _, ok := item["op"]; ok {
		return item
	}
	legacyType, ok := item["type"]
	if !ok {
		return item
	}
	var value string
	if json.Unmarshal(legacyType, &value) != nil {
		return item
	}
	switch value {
	case "set_meta", "set_code", "set_methods", "set_init_args", "set_method", "declare_method", "set_method_inputs", "set_method_outputs":
		copy := make(map[string]json.RawMessage, len(item))
		for key, raw := range item {
			if key != "type" {
				copy[key] = raw
			}
		}
		copy["op"] = legacyType
		return copy
	default:
		return item
	}
}

func normalizeLegacySetCode(item map[string]json.RawMessage, includeMethods bool) ([]json.RawMessage, error) {
	if err := rejectUnknownLegacyKeys(item, "op", "code", "language", "runtime", "runtimeVersion", "pythonVersion"); err != nil {
		return nil, err
	}
	var code string
	if err := json.Unmarshal(item["code"], &code); err != nil || strings.TrimSpace(code) == "" {
		return nil, fmt.Errorf("set_code compatibility requires a non-empty Python class code string")
	}
	var language string
	if raw := item["language"]; len(raw) > 0 && json.Unmarshal(raw, &language) == nil && language != "" && !strings.EqualFold(language, "python") {
		return nil, fmt.Errorf("set_code compatibility only accepts Python class code, got language %q", language)
	}
	var pythonVersion string
	for _, key := range []string{"pythonVersion", "runtimeVersion", "runtime"} {
		if raw := item[key]; len(raw) > 0 {
			if err := json.Unmarshal(raw, &pythonVersion); err != nil {
				return nil, fmt.Errorf("set_code compatibility field %q must be a string", key)
			}
			pythonVersion = normalizePythonVersion(pythonVersion)
			break
		}
	}
	return legacyClassCodeOps(code, pythonVersion, includeMethods)
}

func normalizePythonVersion(value string) string {
	value = strings.TrimSpace(value)
	if strings.HasPrefix(strings.ToLower(value), "python") {
		value = strings.TrimSpace(value[len("python"):])
	}
	return value
}

func normalizeLegacySetMethods(item map[string]json.RawMessage, preferUpdate bool, existingMethods map[string]struct{}) ([]json.RawMessage, error) {
	if err := rejectUnknownLegacyKeys(item, "op", "methods"); err != nil {
		return nil, err
	}
	var methods []json.RawMessage
	if err := json.Unmarshal(item["methods"], &methods); err != nil || methods == nil {
		return nil, fmt.Errorf("set_methods compatibility requires a methods array")
	}
	result := make([]json.RawMessage, 0, len(methods))
	for i, raw := range methods {
		var methodRaw json.RawMessage = raw
		var wrapped struct {
			Method json.RawMessage `json:"method"`
		}
		if err := json.Unmarshal(raw, &wrapped); err == nil && len(bytes.TrimSpace(wrapped.Method)) > 0 {
			methodRaw = wrapped.Method
		}
		method, err := legacyMethodSpec(methodRaw)
		if err != nil {
			return nil, fmt.Errorf("set_methods compatibility methods[%d]: %w", i, err)
		}
		var value []byte
		useUpdate := preferUpdate
		if existingMethods != nil {
			_, useUpdate = existingMethods[method.Name]
		}
		if useUpdate {
			patch := map[string]any{}
			if method.Description != "" {
				patch["description"] = method.Description
			}
			if method.Inputs != nil {
				patch["inputs"] = method.Inputs
			}
			if method.Outputs != nil {
				patch["outputs"] = method.Outputs
			}
			if method.Body != "" {
				patch["body"] = method.Body
			}
			if method.Streaming {
				patch["streaming"] = true
			}
			if method.Timeout != 0 {
				patch["timeout"] = method.Timeout
			}
			if len(patch) == 0 {
				continue
			}
			value, err = json.Marshal(map[string]any{"op": "update_method", "name": method.Name, "patch": patch})
		} else {
			if method.Body == "" {
				return nil, fmt.Errorf("set_methods compatibility methods[%d] requires body when no class method is supplied", i)
			}
			value, err = json.Marshal(map[string]any{"op": "add_method", "method": method})
		}
		if err != nil {
			return nil, fmt.Errorf("set_methods compatibility methods[%d]: %w", i, err)
		}
		result = append(result, value)
	}
	return result, nil
}

func legacyMethodSpec(raw json.RawMessage) (handlerdomain.MethodSpec, error) {
	var method handlerdomain.MethodSpec
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil || fields == nil {
		return method, fmt.Errorf("is not a method object")
	}
	method.Name = stringValue(fields["name"])
	method.Description = stringValue(fields["description"])
	if value := fields["body"]; len(value) > 0 {
		if err := json.Unmarshal(value, &method.Body); err != nil {
			return method, fmt.Errorf("body: %w", err)
		}
	}
	if value := fields["streaming"]; len(value) > 0 {
		if err := json.Unmarshal(value, &method.Streaming); err != nil {
			return method, fmt.Errorf("streaming: %w", err)
		}
	}
	if value := fields["timeout"]; len(value) > 0 {
		if err := json.Unmarshal(value, &method.Timeout); err != nil {
			return method, fmt.Errorf("timeout: %w", err)
		}
	}
	if method.Name == "" {
		return method, fmt.Errorf("requires name")
	}
	if method.Inputs == nil {
		for _, key := range []string{"inputs", "args", "parameters"} {
			if value := fields[key]; len(value) > 0 {
				converted, err := legacyMethodFields(value)
				if err != nil {
					return method, fmt.Errorf("%s: %w", key, err)
				}
				method.Inputs = converted
				break
			}
		}
	}
	if method.Outputs == nil {
		for _, key := range []string{"outputs", "returns"} {
			if value := fields[key]; len(value) > 0 && !bytes.Equal(bytes.TrimSpace(value), []byte("null")) {
				converted, err := legacyMethodFields(value)
				if err != nil {
					return method, fmt.Errorf("%s: %w", key, err)
				}
				method.Outputs = converted
				break
			}
		}
	}
	if value := fields["yields"]; len(value) > 0 && !bytes.Equal(bytes.TrimSpace(value), []byte("null")) {
		method.Streaming = true
	}
	return method, nil
}

func legacyMethodListNeedsClassMethods(item map[string]json.RawMessage) bool {
	var methods []json.RawMessage
	if err := json.Unmarshal(item["methods"], &methods); err != nil {
		return false
	}
	for _, raw := range methods {
		var wrapped struct {
			Method json.RawMessage `json:"method"`
		}
		if err := json.Unmarshal(raw, &wrapped); err == nil && len(bytes.TrimSpace(wrapped.Method)) > 0 {
			raw = wrapped.Method
		}
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(raw, &fields); err != nil || fields == nil {
			return false
		}
		body := stringValue(fields["body"])
		if strings.TrimSpace(body) == "" {
			return true
		}
	}
	return false
}

func normalizeLegacySetInitArgs(item map[string]json.RawMessage) ([]json.RawMessage, error) {
	if err := rejectUnknownLegacyKeys(item, "op", "schema", "config", "initArgs"); err != nil {
		return nil, err
	}
	schemaRaw := item["schema"]
	if len(schemaRaw) == 0 {
		schemaRaw = item["initArgs"]
	}
	if len(schemaRaw) == 0 {
		var config map[string]json.RawMessage
		if err := json.Unmarshal(item["config"], &config); err != nil || config == nil {
			return nil, fmt.Errorf("set_init_args compatibility config must be an object when schema is absent")
		}
		if len(config) > 0 {
			return nil, fmt.Errorf("set_init_args compatibility cannot infer init-arg schema from non-empty config; use set_init_args_schema with typed args")
		}
		value, err := json.Marshal(map[string]any{"op": "set_init_args_schema", "args": []handlerdomain.InitArgSpec{}})
		if err != nil {
			return nil, fmt.Errorf("set_init_args compatibility: %w", err)
		}
		return []json.RawMessage{value}, nil
	}
	if schema := bytes.TrimSpace(schemaRaw); len(schema) > 0 && schema[0] == '[' {
		var args []handlerdomain.InitArgSpec
		if err := json.Unmarshal(schema, &args); err != nil {
			return nil, fmt.Errorf("set_init_args compatibility schema array must contain InitArgSpec values: %w", err)
		}
		value, err := json.Marshal(map[string]any{"op": "set_init_args_schema", "args": args})
		if err != nil {
			return nil, fmt.Errorf("set_init_args compatibility: %w", err)
		}
		return []json.RawMessage{value}, nil
	}
	var schema struct {
		Properties map[string]struct {
			Type        string          `json:"type"`
			Description string          `json:"description"`
			Required    *bool           `json:"required"`
			Sensitive   bool            `json:"sensitive"`
			Default     json.RawMessage `json:"default"`
		} `json:"properties"`
		Required []string `json:"required"`
	}
	if err := json.Unmarshal(schemaRaw, &schema); err != nil {
		return nil, fmt.Errorf("set_init_args compatibility schema must be a JSON Schema object: %w", err)
	}
	required := make(map[string]bool, len(schema.Required))
	for _, name := range schema.Required {
		required[name] = true
	}
	names := make([]string, 0, len(schema.Properties))
	for name := range schema.Properties {
		names = append(names, name)
	}
	sort.Strings(names)
	args := make([]handlerdomain.InitArgSpec, 0, len(names))
	for _, name := range names {
		property := schema.Properties[name]
		arg := handlerdomain.InitArgSpec{
			Name:        name,
			Type:        legacyInitArgType(property.Type),
			Description: property.Description,
			Required:    required[name],
			Sensitive:   property.Sensitive,
		}
		if property.Required != nil {
			arg.Required = *property.Required
		}
		if len(bytes.TrimSpace(property.Default)) > 0 && !bytes.Equal(bytes.TrimSpace(property.Default), []byte("null")) {
			if err := json.Unmarshal(property.Default, &arg.Default); err != nil {
				return nil, fmt.Errorf("set_init_args compatibility property %q default: %w", name, err)
			}
		}
		args = append(args, arg)
	}
	value, err := json.Marshal(map[string]any{"op": "set_init_args_schema", "args": args})
	if err != nil {
		return nil, fmt.Errorf("set_init_args compatibility: %w", err)
	}
	return []json.RawMessage{value}, nil
}

func normalizeLegacySetMethod(item map[string]json.RawMessage, hasLegacyClassCode bool) ([]json.RawMessage, error) {
	if err := rejectUnknownLegacyKeys(item, "op", "method", "description", "parameters", "inputs", "outputs", "body", "streaming", "timeout", "args", "returns", "yields"); err != nil {
		return nil, err
	}
	var methodObject handlerdomain.MethodSpec
	if raw := item["method"]; len(raw) > 0 && raw[0] == '{' {
		if err := json.Unmarshal(raw, &methodObject); err != nil {
			return nil, fmt.Errorf("set_method compatibility method object: %w", err)
		}
	} else {
		if err := json.Unmarshal(item["method"], &methodObject.Name); err != nil || methodObject.Name == "" {
			return nil, fmt.Errorf("set_method compatibility requires a method name")
		}
		methodObject.Description = stringValue(item["description"])
		if raw := item["inputs"]; len(raw) > 0 {
			if err := json.Unmarshal(raw, &methodObject.Inputs); err != nil {
				return nil, fmt.Errorf("set_method compatibility inputs: %w", err)
			}
		} else if raw := item["parameters"]; len(raw) > 0 {
			fields, err := legacyMethodFields(raw)
			if err != nil {
				return nil, fmt.Errorf("set_method compatibility parameters: %w", err)
			}
			methodObject.Inputs = fields
		}
		if raw := item["args"]; len(raw) > 0 && methodObject.Inputs == nil {
			fields, err := legacyMethodFields(raw)
			if err != nil {
				return nil, fmt.Errorf("set_method compatibility args: %w", err)
			}
			methodObject.Inputs = fields
		}
		if raw := item["outputs"]; len(raw) > 0 {
			fields, err := legacyMethodFields(raw)
			if err != nil {
				return nil, fmt.Errorf("set_method compatibility outputs: %w", err)
			}
			methodObject.Outputs = fields
		}
		if raw := item["returns"]; len(raw) > 0 && !bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
			fields, err := legacyMethodFields(raw)
			if err != nil {
				return nil, fmt.Errorf("set_method compatibility returns: %w", err)
			}
			methodObject.Outputs = fields
		}
		if raw := item["body"]; len(raw) > 0 {
			if err := json.Unmarshal(raw, &methodObject.Body); err != nil {
				return nil, fmt.Errorf("set_method compatibility body: %w", err)
			}
		}
		if raw := item["streaming"]; len(raw) > 0 {
			if err := json.Unmarshal(raw, &methodObject.Streaming); err != nil {
				return nil, fmt.Errorf("set_method compatibility streaming: %w", err)
			}
		}
		if raw := item["yields"]; len(raw) > 0 && !bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
			methodObject.Streaming = true
		}
		if raw := item["timeout"]; len(raw) > 0 {
			if err := json.Unmarshal(raw, &methodObject.Timeout); err != nil {
				return nil, fmt.Errorf("set_method compatibility timeout: %w", err)
			}
		}
	}
	if methodObject.Name == "" {
		return nil, fmt.Errorf("set_method compatibility requires a method name")
	}
	if methodObject.Body == "" && hasLegacyClassCode {
		patch := map[string]any{}
		if methodObject.Description != "" {
			patch["description"] = methodObject.Description
		}
		if methodObject.Inputs != nil {
			patch["inputs"] = methodObject.Inputs
		}
		if methodObject.Outputs != nil {
			patch["outputs"] = methodObject.Outputs
		}
		if methodObject.Streaming {
			patch["streaming"] = true
		}
		if methodObject.Timeout != 0 {
			patch["timeout"] = methodObject.Timeout
		}
		if len(patch) == 0 {
			return []json.RawMessage{}, nil
		}
		value, err := json.Marshal(map[string]any{"op": "update_method", "name": methodObject.Name, "patch": patch})
		if err != nil {
			return nil, fmt.Errorf("set_method compatibility update: %w", err)
		}
		return []json.RawMessage{value}, nil
	}
	value, err := json.Marshal(map[string]any{"op": "add_method", "method": methodObject})
	if err != nil {
		return nil, fmt.Errorf("set_method compatibility add: %w", err)
	}
	return []json.RawMessage{value}, nil
}

func normalizeLegacyDeclareMethod(item map[string]json.RawMessage, hasLegacyClassCode bool) ([]json.RawMessage, error) {
	if err := rejectUnknownLegacyKeys(item, "op", "name", "description", "parameters", "inputs", "outputs", "body", "streaming", "timeout"); err != nil {
		return nil, err
	}
	name := stringValue(item["name"])
	if name == "" {
		return nil, fmt.Errorf("declare_method compatibility requires a method name")
	}
	if raw := item["body"]; len(raw) > 0 {
		var method handlerdomain.MethodSpec
		method.Name = name
		method.Description = stringValue(item["description"])
		if err := json.Unmarshal(raw, &method.Body); err != nil {
			return nil, fmt.Errorf("declare_method compatibility body: %w", err)
		}
		if raw := item["inputs"]; len(raw) > 0 {
			fields, err := legacyMethodFields(raw)
			if err != nil {
				return nil, fmt.Errorf("declare_method compatibility inputs: %w", err)
			}
			method.Inputs = fields
		}
		if raw := item["parameters"]; len(raw) > 0 && method.Inputs == nil {
			fields, err := legacyMethodFields(raw)
			if err != nil {
				return nil, fmt.Errorf("declare_method compatibility parameters: %w", err)
			}
			method.Inputs = fields
		}
		if raw := item["outputs"]; len(raw) > 0 {
			fields, err := legacyMethodFields(raw)
			if err != nil {
				return nil, fmt.Errorf("declare_method compatibility outputs: %w", err)
			}
			method.Outputs = fields
		}
		if raw := item["streaming"]; len(raw) > 0 {
			if err := json.Unmarshal(raw, &method.Streaming); err != nil {
				return nil, fmt.Errorf("declare_method compatibility streaming: %w", err)
			}
		}
		if raw := item["timeout"]; len(raw) > 0 {
			if err := json.Unmarshal(raw, &method.Timeout); err != nil {
				return nil, fmt.Errorf("declare_method compatibility timeout: %w", err)
			}
		}
		value, err := json.Marshal(map[string]any{"op": "add_method", "method": method})
		if err != nil {
			return nil, fmt.Errorf("declare_method compatibility add: %w", err)
		}
		return []json.RawMessage{value}, nil
	}
	patch := make(map[string]any)
	if description := stringValue(item["description"]); description != "" {
		patch["description"] = description
	}
	if raw := item["inputs"]; len(raw) > 0 {
		fields, err := legacyMethodFields(raw)
		if err != nil {
			return nil, fmt.Errorf("declare_method compatibility inputs: %w", err)
		}
		patch["inputs"] = fields
	}
	if raw := item["parameters"]; len(raw) > 0 {
		fields, err := legacyMethodFields(raw)
		if err != nil {
			return nil, fmt.Errorf("declare_method compatibility parameters: %w", err)
		}
		patch["inputs"] = fields
	}
	if raw := item["outputs"]; len(raw) > 0 {
		fields, err := legacyMethodFields(raw)
		if err != nil {
			return nil, fmt.Errorf("declare_method compatibility outputs: %w", err)
		}
		patch["outputs"] = fields
	}
	if raw := item["streaming"]; len(raw) > 0 {
		var value bool
		if err := json.Unmarshal(raw, &value); err != nil {
			return nil, fmt.Errorf("declare_method compatibility streaming: %w", err)
		}
		patch["streaming"] = value
	}
	if raw := item["timeout"]; len(raw) > 0 {
		var value int
		if err := json.Unmarshal(raw, &value); err != nil {
			return nil, fmt.Errorf("declare_method compatibility timeout: %w", err)
		}
		patch["timeout"] = value
	}
	if len(patch) == 0 {
		if !hasLegacyClassCode {
			return nil, fmt.Errorf("declare_method compatibility requires set_code or a complete method body")
		}
		return []json.RawMessage{}, nil
	}
	value, err := json.Marshal(map[string]any{"op": "update_method", "name": name, "patch": patch})
	if err != nil {
		return nil, fmt.Errorf("declare_method compatibility update: %w", err)
	}
	return []json.RawMessage{value}, nil
}

func normalizeLegacyMethodFields(item map[string]json.RawMessage, patchField, rawField string) ([]json.RawMessage, error) {
	if err := rejectUnknownLegacyKeys(item, "op", "method", "methodName", rawField, "schema"); err != nil {
		return nil, err
	}
	name := stringValue(item["method"])
	if name == "" {
		name = stringValue(item["methodName"])
	}
	if name == "" {
		return nil, fmt.Errorf("%s compatibility requires a method name", stringValue(item["op"]))
	}
	raw := item[rawField]
	if len(raw) == 0 {
		raw = item["schema"]
	}
	if len(raw) == 0 {
		return nil, fmt.Errorf("%s compatibility requires %s", stringValue(item["op"]), rawField)
	}
	fields, err := legacyMethodFields(raw)
	if err != nil {
		return nil, fmt.Errorf("%s compatibility %s: %w", stringValue(item["op"]), rawField, err)
	}
	value, err := json.Marshal(map[string]any{
		"op":    "update_method",
		"name":  name,
		"patch": map[string]any{patchField: fields},
	})
	if err != nil {
		return nil, fmt.Errorf("%s compatibility update: %w", stringValue(item["op"]), err)
	}
	return []json.RawMessage{value}, nil
}

func legacyMethodFields(raw json.RawMessage) ([]schemapkg.Field, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) > 0 && trimmed[0] == '[' {
		var fields []schemapkg.Field
		if err := json.Unmarshal(trimmed, &fields); err != nil {
			return nil, fmt.Errorf("field array must be valid JSON: %w", err)
		}
		return fields, nil
	}
	return legacySchemaFields(raw)
}

func legacySchemaFields(raw json.RawMessage) ([]schemapkg.Field, error) {
	var schema struct {
		Properties map[string]struct {
			Type        string `json:"type"`
			Description string `json:"description"`
		} `json:"properties"`
	}
	if err := json.Unmarshal(raw, &schema); err != nil {
		return nil, fmt.Errorf("schema must be an object: %w", err)
	}
	names := make([]string, 0, len(schema.Properties))
	for name := range schema.Properties {
		names = append(names, name)
	}
	sort.Strings(names)
	fields := make([]schemapkg.Field, 0, len(names))
	for _, name := range names {
		property := schema.Properties[name]
		fields = append(fields, schemapkg.Field{Name: name, Type: legacyFieldType(property.Type), Description: property.Description})
	}
	return fields, nil
}

func legacyClassCodeOps(code, pythonVersion string, includeMethods bool) ([]json.RawMessage, error) {
	code = stripPythonFence(code)
	lines := strings.Split(strings.ReplaceAll(code, "\r\n", "\n"), "\n")
	classLine := -1
	classIndent := 0
	for i, line := range lines {
		if indentWidth(line) == 0 && strings.HasPrefix(strings.TrimSpace(line), "class ") {
			classLine = i
			break
		}
	}
	if classLine < 0 {
		return nil, fmt.Errorf("set_code compatibility needs a Python class with methods; use add_method instead of a whole code blob")
	}
	classIndent = indentWidth(lines[classLine])

	result := make([]json.RawMessage, 0, 4)
	imports := make([]string, 0)
	for _, line := range lines[:classLine] {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "import ") || strings.HasPrefix(trimmed, "from ") {
			imports = append(imports, trimmed)
		}
	}
	if len(imports) > 0 {
		value, err := json.Marshal(map[string]any{"op": "set_imports", "imports": strings.Join(imports, "\n")})
		if err != nil {
			return nil, fmt.Errorf("set_code compatibility imports: %w", err)
		}
		result = append(result, value)
	}
	if pythonVersion != "" {
		value, err := json.Marshal(map[string]any{"op": "set_python_version", "version": pythonVersion})
		if err != nil {
			return nil, fmt.Errorf("set_code compatibility python version: %w", err)
		}
		result = append(result, value)
	}

	methods, err := legacyClassMethods(lines, classLine, classIndent)
	if err != nil {
		return nil, err
	}
	methodCount := 0
	for _, method := range methods {
		switch method.Name {
		case "__init__":
			value, marshalErr := json.Marshal(map[string]any{"op": "set_init", "initBody": method.Body})
			if marshalErr != nil {
				return nil, fmt.Errorf("set_code compatibility __init__: %w", marshalErr)
			}
			result = append(result, value)
		case "shutdown":
			value, marshalErr := json.Marshal(map[string]any{"op": "set_shutdown", "shutdownBody": method.Body})
			if marshalErr != nil {
				return nil, fmt.Errorf("set_code compatibility shutdown: %w", marshalErr)
			}
			result = append(result, value)
		default:
			if !includeMethods {
				continue
			}
			value, marshalErr := json.Marshal(map[string]any{"op": "add_method", "method": method})
			if marshalErr != nil {
				return nil, fmt.Errorf("set_code compatibility method %q: %w", method.Name, marshalErr)
			}
			result = append(result, value)
			methodCount++
		}
	}
	if includeMethods && methodCount == 0 {
		return nil, fmt.Errorf("set_code compatibility found no callable class method; use add_method with a complete MethodSpec")
	}
	return result, nil
}

func legacyClassMethods(lines []string, classLine, classIndent int) ([]handlerdomain.MethodSpec, error) {
	methods := make([]handlerdomain.MethodSpec, 0)
	for i := classLine + 1; i < len(lines); i++ {
		line := lines[i]
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") || indentWidth(line) > classIndent+4 {
			continue
		}
		if indentWidth(line) < classIndent+4 {
			break
		}
		if indentWidth(line) != classIndent+4 || (!strings.HasPrefix(trimmed, "def ") && !strings.HasPrefix(trimmed, "async def ")) {
			continue
		}
		name, params, err := legacyMethodSignature(trimmed)
		if err != nil {
			return nil, fmt.Errorf("set_code compatibility: %w", err)
		}
		end := i + 1
		for end < len(lines) {
			next := lines[end]
			nextTrimmed := strings.TrimSpace(next)
			if nextTrimmed != "" && indentWidth(next) <= classIndent+4 && indentWidth(next) != classIndent+4 {
				break
			}
			if indentWidth(next) == classIndent+4 && (strings.HasPrefix(nextTrimmed, "def ") || strings.HasPrefix(nextTrimmed, "async def ")) {
				break
			}
			end++
		}
		body := dedentLegacyPython(strings.Join(lines[i+1:end], "\n"))
		methods = append(methods, handlerdomain.MethodSpec{Name: name, Inputs: params, Body: body, Streaming: false})
		i = end - 1
	}
	return methods, nil
}

func legacyMethodSignature(header string) (string, []schemapkg.Field, error) {
	if strings.HasPrefix(header, "async def ") {
		header = strings.TrimPrefix(header, "async ")
	}
	header = strings.TrimSuffix(header, ":")
	open := strings.IndexByte(header, '(')
	close := strings.LastIndexByte(header, ')')
	if open <= len("def ") || close < open {
		return "", nil, fmt.Errorf("cannot parse method signature %q", header)
	}
	name := strings.TrimSpace(header[len("def "):open])
	if name == "" {
		return "", nil, fmt.Errorf("method name is empty in %q", header)
	}
	params := splitLegacyPythonArgs(header[open+1 : close])
	fields := make([]schemapkg.Field, 0, len(params))
	for _, raw := range params {
		param := strings.TrimSpace(raw)
		param = strings.TrimLeft(param, "*")
		if param == "" || param == "self" || param == "cls" {
			continue
		}
		param = splitLegacyPythonAtTopLevel(param, '=')[0]
		parts := splitLegacyPythonAtTopLevel(param, ':')
		fieldName := strings.TrimSpace(parts[0])
		if fieldName == "" {
			return "", nil, fmt.Errorf("method %q has an unparseable parameter %q", name, raw)
		}
		fieldType := "object"
		if len(parts) > 1 {
			fieldType = legacyFieldType(strings.TrimSpace(parts[1]))
		}
		fields = append(fields, schemapkg.Field{Name: fieldName, Type: fieldType})
	}
	return name, fields, nil
}

func splitLegacyPythonArgs(s string) []string {
	parts := make([]string, 0, 4)
	start, depth := 0, 0
	var quote byte
	for i := 0; i < len(s); i++ {
		c := s[i]
		if quote != 0 {
			if c == quote && (i == 0 || s[i-1] != '\\') {
				quote = 0
			}
			continue
		}
		if c == '\'' || c == '"' {
			quote = c
			continue
		}
		switch c {
		case '(', '[', '{':
			depth++
		case ')', ']', '}':
			if depth > 0 {
				depth--
			}
		case ',':
			if depth == 0 {
				parts = append(parts, strings.TrimSpace(s[start:i]))
				start = i + 1
			}
		}
	}
	if tail := strings.TrimSpace(s[start:]); tail != "" {
		parts = append(parts, tail)
	}
	return parts
}

func splitLegacyPythonAtTopLevel(s string, separator byte) []string {
	depth := 0
	var quote byte
	for i := 0; i < len(s); i++ {
		c := s[i]
		if quote != 0 {
			if c == quote && (i == 0 || s[i-1] != '\\') {
				quote = 0
			}
			continue
		}
		if c == '\'' || c == '"' {
			quote = c
			continue
		}
		switch c {
		case '(', '[', '{':
			depth++
		case ')', ']', '}':
			if depth > 0 {
				depth--
			}
		default:
			if c == separator && depth == 0 {
				return []string{strings.TrimSpace(s[:i]), strings.TrimSpace(s[i+1:])}
			}
		}
	}
	return []string{strings.TrimSpace(s)}
}

func dedentLegacyPython(s string) string {
	lines := strings.Split(s, "\n")
	common := -1
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		indent := indentWidth(line)
		if common < 0 || indent < common {
			common = indent
		}
	}
	if common <= 0 {
		return strings.TrimSuffix(s, "\n")
	}
	for i, line := range lines {
		if strings.TrimSpace(line) == "" {
			lines[i] = ""
			continue
		}
		removed, bytesSeen := 0, 0
		for _, r := range line {
			if removed >= common || (r != ' ' && r != '\t') {
				break
			}
			bytesSeen += len(string(r))
			removed++
		}
		lines[i] = line[bytesSeen:]
	}
	return strings.TrimSuffix(strings.Join(lines, "\n"), "\n")
}

func indentWidth(line string) int {
	width := 0
	for _, r := range line {
		switch r {
		case ' ':
			width++
		case '\t':
			width += 4
		default:
			return width
		}
	}
	return width
}

func stripPythonFence(code string) string {
	code = strings.TrimSpace(code)
	if strings.HasPrefix(code, "```") {
		if newline := strings.IndexByte(code, '\n'); newline >= 0 {
			code = code[newline+1:]
		}
		code = strings.TrimSuffix(strings.TrimSpace(code), "```")
	}
	return strings.TrimSpace(code)
}

func rejectUnknownLegacyKeys(item map[string]json.RawMessage, allowed ...string) error {
	known := make(map[string]bool, len(allowed))
	for _, key := range allowed {
		known[key] = true
	}
	for key := range item {
		if !known[key] {
			return fmt.Errorf("legacy handler op %q has unknown field %q", stringValue(item["op"]), key)
		}
	}
	return nil
}

func stringValue(raw json.RawMessage) string {
	var value string
	if json.Unmarshal(raw, &value) == nil {
		return value
	}
	return ""
}

func legacyFieldType(annotation string) string {
	annotation = strings.ToLower(strings.TrimSpace(annotation))
	annotation = strings.Trim(annotation, "[]")
	switch annotation {
	case "str", "string":
		return schemapkg.TypeString
	case "int", "integer", "float", "number", "double":
		return schemapkg.TypeNumber
	case "bool", "boolean":
		return schemapkg.TypeBoolean
	case "list", "array", "tuple", "sequence":
		return schemapkg.TypeArray
	case "dict", "object", "mapping":
		return schemapkg.TypeObject
	default:
		return schemapkg.TypeObject
	}
}

func legacyInitArgType(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "integer", "int", "float", "number", "double":
		return "number"
	case "boolean", "bool":
		return "boolean"
	case "array", "list":
		return "array"
	case "object", "dict", "map", "":
		return "object"
	default:
		return "string"
	}
}
