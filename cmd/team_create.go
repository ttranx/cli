// Copyright © 2016 Paul Allen <paul@cloudcoreo.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"io"

	"github.com/CloudCoreo/cli/cmd/content"
	"github.com/CloudCoreo/cli/cmd/util"
	"github.com/CloudCoreo/cli/pkg/coreo"
	"github.com/spf13/cobra"
)

type teamCreateCmd struct {
	out             io.Writer
	client          coreo.Interface
	teamName        string
	teamDescription string
}

func newTeamCreateCmd(client coreo.Interface, out io.Writer) *cobra.Command {
	teamCreate := &teamCreateCmd{
		out:    out,
		client: client,
	}

	cmd := &cobra.Command{
		Use:   content.CmdAddUse,
		Short: content.CmdTeamAddShort,
		Long:  content.CmdTeamAddLong,
		RunE: func(cmd *cobra.Command, args []string) error {

			if err := util.CheckTeamAddFlags(teamCreate.teamName, teamCreate.teamDescription); err != nil {
				return err
			}

			if teamCreate.client == nil {
				teamCreate.client = coreo.NewClient(
					coreo.Host(apiEndpoint),
					coreo.APIKey(key),
					coreo.SecretKey(secret))
			}

			return teamCreate.run()
		},
	}

	f := cmd.Flags()

	f.StringVarP(&teamCreate.teamName, content.CmdFlagNameLong, content.CmdFlagNameShort, "", content.CmdTeamNameDescription)
	f.StringVarP(&teamCreate.teamDescription, content.CmdFlagDescriptionLong, content.CmdFlagDescriptionShort, "", content.CmdTeamDescriptionDescription)

	return cmd
}

func (t *teamCreateCmd) run() error {
	team, err := t.client.CreateTeam(t.teamName, t.teamDescription)
	if err != nil {
		return err
	}

	util.PrintResult(
		t.out,
		team,
		[]string{"ID", "TeamName", "TeamDescription"},
		map[string]string{
			"ID":              "Team ID",
			"TeamName":        "Team Name",
			"TeamDescription": "Team Description",
		},
		jsonFormat,
		verbose)

	return nil
}
