package ingest

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
)

// Cursor is the opaque keyset pagination position for List.
// The wire form is base64(JSON({"l":lamport,"i":id})); callers should
// treat the encoded string as opaque (the field names are abbreviated
// to keep the payload short, not as a public contract).
//
// A zero Cursor (both fields 0) represents "before the first row" and
// is what the first page request uses. After the last page List
// returns an empty next-cursor string.
type Cursor struct {
	Lamport int64
	ID      int64
}

type cursorWire struct {
	L int64 `json:"l"`
	I int64 `json:"i"`
}

// EncodeCursor serializes c to its base64 wire form. A zero Cursor
// (Lamport == 0 && ID == 0) encodes to "" so callers can treat
// end-of-stream and start-of-stream symmetrically.
func EncodeCursor(c Cursor) string {
	if c.Lamport == 0 && c.ID == 0 {
		return ""
	}
	raw, _ := json.Marshal(cursorWire{L: c.Lamport, I: c.ID}) // cannot fail
	return base64.RawURLEncoding.EncodeToString(raw)
}

// DecodeCursor parses a wire-form cursor. Empty string returns the
// zero Cursor (start-of-stream) without error.
//
// We reject negative values up front — they can't appear in a
// legitimately-encoded cursor and skipping the check would let a
// malicious client probe rows from before the intended position.
func DecodeCursor(s string) (Cursor, error) {
	if s == "" {
		return Cursor{}, nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return Cursor{}, fmt.Errorf("cursor: base64 decode: %w", err)
	}
	var w cursorWire
	if err := json.Unmarshal(raw, &w); err != nil {
		return Cursor{}, fmt.Errorf("cursor: json decode: %w", err)
	}
	if w.L < 0 || w.I < 0 {
		return Cursor{}, errors.New("cursor: negative fields not allowed")
	}
	return Cursor{Lamport: w.L, ID: w.I}, nil
}
