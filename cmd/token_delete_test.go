package main

import (
	"bytes"
	"regexp"
	"testing"

	"github.com/CloudCoreo/cli/client"
	"github.com/pkg/errors"
)

func TestTokenDeleteCmd(t *testing.T) {
	mockToken := func(tokenName, tokenID, tokenDescription string) *client.Token {
		return &client.Token{
			ID:          tokenID,
			Description: tokenDescription,
			Name:        tokenName,
		}
	}

	tests := []struct {
		cmds  string
		desc  string
		flags []string
		args  []string
		resp  []*client.Token
		json  bool
		err   bool
		xout  string
	}{
		{
			cmds: "coreo token delete",
			desc: "delete a particular token",
			flags: []string{
				"--token-id", "123",
			},
			resp: []*client.Token{
				mockToken("ID1", "TokenDescription1", "TokenName1"),
				mockToken("ID2", "TokenDescription2", "TokenName2"),
			},
			xout: "",
		},
		{
			cmds: "coreo token delete",
			desc: "delete a particular token",
			args: []string{""},
			err:  true,
		},
	}

	var buf bytes.Buffer
	for _, tt := range tests {
		frc := &fakeReleaseClient{tokens: tt.resp}
		if tt.err {
			frc.err = errors.New("Error")
		}

		cmd := newTokenDeleteCmd(frc, &buf)
		cmd.ParseFlags(tt.flags)
		err := cmd.RunE(cmd, tt.args)

		if (err != nil) != tt.err {
			t.Errorf("%q. expected error, got '%v'", tt.desc, err)
		}

		re := regexp.MustCompile(tt.xout)
		if !re.Match(buf.Bytes()) {
			t.Fatalf("%q\n\t%s:\nexpected\n\t%q\nactual\n\t%q", tt.cmds, tt.desc, tt.xout, buf.String())
		}
		buf.Reset()
	}
}
