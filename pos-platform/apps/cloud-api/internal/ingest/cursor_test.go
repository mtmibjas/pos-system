package ingest_test

import (
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
)

func TestCursor_RoundTrip(t *testing.T) {
	cases := []ingest.Cursor{
		{Lamport: 1, ID: 1},
		{Lamport: 42, ID: 7},
		{Lamport: 1 << 40, ID: 1 << 30},
	}
	for _, c := range cases {
		enc := ingest.EncodeCursor(c)
		require.NotEmpty(t, enc, "non-zero cursor must encode to non-empty string")
		got, err := ingest.DecodeCursor(enc)
		require.NoError(t, err)
		require.Equal(t, c, got)
	}
}

func TestCursor_ZeroEncodesEmpty(t *testing.T) {
	require.Equal(t, "", ingest.EncodeCursor(ingest.Cursor{}),
		"zero cursor is start-of-stream and end-of-stream — encode to empty")
}

func TestCursor_DecodeEmptyIsZero(t *testing.T) {
	c, err := ingest.DecodeCursor("")
	require.NoError(t, err)
	require.Equal(t, ingest.Cursor{}, c)
}

func TestCursor_DecodeRejectsGarbage(t *testing.T) {
	_, err := ingest.DecodeCursor("not-base64-!!!")
	require.Error(t, err)
}

func TestCursor_DecodeRejectsNegative(t *testing.T) {
	// Hand-craft a payload with negative lamport.
	bad := "eyJsIjotMSwiaSI6MX0" // base64url of {"l":-1,"i":1}
	_, err := ingest.DecodeCursor(bad)
	require.Error(t, err)
}
