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

package cmd

import (
	"context"
	"fmt"
	"os"

	"github.com/CloudCoreo/cli/client"
	"github.com/CloudCoreo/cli/cmd/content"
	"github.com/CloudCoreo/cli/cmd/util"
	"github.com/spf13/cobra"
)

// GitKeyDeleteCmd represents the based command for gitkey subcommands
var GitKeyDeleteCmd = &cobra.Command{
	Use:   content.CMD_GITKEY_DELETE_USE,
	Short: content.CMD_GITKEY_DELETE_SHORT,
	Long:  content.CMD_GITKEY_DELETE_LONG,
	PreRun: func(cmd *cobra.Command, args []string) {
		if err := util.CheckGitKeyShowOrDeleteFlag(cloudID); err != nil {
			fmt.Fprintf(os.Stderr, err.Error())
			os.Exit(-1)
		}
		SetupCoreoCredentials()
		SetupCoreoDefaultTeam()

	},
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println(key, secret)
		c, err := client.MakeClient(key, secret, content.ENDPOINT_ADDRESS)

		if err != nil {
			fmt.Fprintf(os.Stderr, err.Error())
			os.Exit(-1)
		}

		err = c.DeleteGitKeyByID(context.Background(), teamID, gitKeyID)
		if err != nil {
			fmt.Fprintf(os.Stderr, err.Error())
			os.Exit(-1)
		}

		fmt.Printf("Git key deleted")
	},
}

func init() {
	GitKeyCmd.AddCommand(GitKeyDeleteCmd)

	GitKeyDeleteCmd.Flags().StringVarP(&gitKeyID, content.CMD_FLAG_ID_LONG, content.CMD_FLAG_ID_SHORT, "", content.CMD_FLAG_CLOUDID_DESCRIPTION)
}