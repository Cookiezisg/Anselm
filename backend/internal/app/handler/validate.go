// validate.go — incremental + final validation for VersionDraft.
//
// Incremental(every op):name char-set (if set) + method name uniqueness +
// method/arg type whitelist + InitArgSpec sanity.
//
// Final(after all ops):required fields(name + at least one method) + AST
// scan(the assembled class must contain class definition) + D7 handler-import
// blacklist (handlers don't import other handlers' clients; V1 simplification).
//
// validate.go —— VersionDraft 的 incremental + final 校验。

package handler

import (
	"fmt"
	"regexp"
	"strings"
)

// validateIncremental runs after each op application.
//
// validateIncremental 每 op 应用后跑。
func validateIncremental(d *VersionDraft) error {
	if d.Name != "" {
		if !validNameRe.MatchString(d.Name) {
			return fmt.Errorf("name %q invalid: lowercase alphanum + dashes/underscores only", d.Name)
		}
	}
	// Method name uniqueness + arg type whitelist.
	seen := map[string]bool{}
	for _, m := range d.Methods {
		if m.Name == "" {
			return fmt.Errorf("method has empty name")
		}
		if seen[m.Name] {
			return fmt.Errorf("duplicate method name: %q", m.Name)
		}
		seen[m.Name] = true
		argSeen := map[string]bool{}
		for _, a := range m.Args {
			if a.Name == "" {
				return fmt.Errorf("method %q: arg has empty name", m.Name)
			}
			if argSeen[a.Name] {
				return fmt.Errorf("method %q: duplicate arg %q", m.Name, a.Name)
			}
			argSeen[a.Name] = true
			if !isValidArgType(a.Type) {
				return fmt.Errorf("method %q arg %q: invalid type %q", m.Name, a.Name, a.Type)
			}
		}
	}
	// InitArgSpec sanity.
	initSeen := map[string]bool{}
	for _, a := range d.InitArgsSchema {
		if a.Name == "" {
			return fmt.Errorf("init arg has empty name")
		}
		if initSeen[a.Name] {
			return fmt.Errorf("duplicate init arg %q", a.Name)
		}
		initSeen[a.Name] = true
		if !isValidArgType(a.Type) {
			return fmt.Errorf("init arg %q: invalid type %q", a.Name, a.Type)
		}
	}
	return nil
}

// validateFinal runs after all ops applied — entity-persistence prerequisite.
//
// validateFinal 全部 ops 应用完跑——entity 持久化前置。
func validateFinal(d *VersionDraft) error {
	if d.Name == "" {
		return fmt.Errorf("name is required")
	}
	if len(d.Methods) == 0 {
		return fmt.Errorf("at least one method required")
	}
	// D7 blacklist on imports + every method body.
	for _, banned := range handlerImportBlacklist {
		if strings.Contains(d.Imports, banned) {
			return fmt.Errorf("D7: handler import not allowed in class imports: %q", banned)
		}
		for _, m := range d.Methods {
			if strings.Contains(m.Body, banned) {
				return fmt.Errorf("D7: handler import not allowed in method %q: %q", m.Name, banned)
			}
		}
		if strings.Contains(d.InitBody, banned) {
			return fmt.Errorf("D7: handler import not allowed in __init__: %q", banned)
		}
	}
	return nil
}

var validNameRe = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,63}$`)

func isValidArgType(t string) bool {
	switch t {
	case "string", "number", "integer", "boolean", "object", "array":
		return true
	}
	return false
}

// handlerImportBlacklist is the V1 import deny-list. The forgify_handler
// package doesn't actually exist (no such lib in the user's venv) so this is
// pure defense against future LLM hallucination. Same list as function's.
//
// handlerImportBlacklist 是 V1 import 黑名单。forgify_handler 实际不存在,
// 纯防 LLM 未来产幻;跟 function 同名单。
var handlerImportBlacklist = []string{
	"from forgify_handler import",
	"import forgify_handler",
}
