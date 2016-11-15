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
	"github.com/CloudCoreo/cli/cmd/content"
	"github.com/spf13/cobra"
)

var gitKeyID string

// GitKeyCmd represents the based command for gitkey subcommands
var GitKeyCmd = &cobra.Command{
	Use:   content.CMD_GITKEY_USE,
	Short: content.CMD_GITKEY_SHORT,
	Long:  content.CMD_GITKEY_LONG,
}

func init() {
	RootCmd.AddCommand(GitKeyCmd)
}