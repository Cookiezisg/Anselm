package document

import (
	"encoding/json"
	"fmt"
	"strings"
)

// decodeDocumentTags accepts the schema-correct array and the one-level JSON-encoded
// array string emitted by some hosted providers. It never guesses arbitrary strings.
func decodeDocumentTags(raw json.RawMessage) (*[]string, error) {
	if len(raw) == 0 || strings.TrimSpace(string(raw)) == "null" {
		return nil, nil
	}

	var tags []string
	if err := json.Unmarshal(raw, &tags); err == nil {
		return &tags, nil
	}

	var encoded string
	if err := json.Unmarshal(raw, &encoded); err != nil || json.Unmarshal([]byte(encoded), &tags) != nil {
		return nil, fmt.Errorf("tags must be a JSON array of strings")
	}
	return &tags, nil
}
