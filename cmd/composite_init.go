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

	"fmt"
	"os"
	"path"

	"github.com/CloudCoreo/cli/cmd/content"
	"github.com/CloudCoreo/cli/cmd/util"
	"github.com/spf13/cobra"
)

type compositeInitCmd struct {
	out       io.Writer
	directory string
	serverDir bool
	audit     bool
}

func newCompositeInitCmd(out io.Writer) *cobra.Command {
	compositeInit := &compositeInitCmd{
		out: out,
	}

	cmd := &cobra.Command{
		Use:   content.CmdInitUse,
		Short: content.CmdCompositeInitShort,
		Long:  content.CmdCompositeInitLong,
		RunE: func(cmd *cobra.Command, args []string) error {
			return compositeInit.run()
		},
	}

	f := cmd.Flags()

	f.StringVarP(&compositeInit.directory, content.CmdFlagDirectoryLong, content.CmdFlagDirectoryShort, "", content.CmdFlagDirectoryDescription)
	f.BoolVarP(&compositeInit.audit, content.CmdFlagAuditLong, content.CmdFlagAuditShort, false, content.CmdFlagAuditDescription)
	f.BoolVarP(&compositeInit.serverDir, content.CmdFlagServerLong, content.CmdFlagServerShort, false, content.CmdFlagServerDescription)

	return cmd
}

func (t *compositeInitCmd) run() error {

	if t.directory == "" {
		t.directory, _ = os.Getwd()
	}

	genContent(t.directory)

	if t.serverDir {
		genServerContent(t.directory)
	} else if t.audit {
		genAuditContent(t.directory)
	}

	return nil
}

func genContent(directory string) {
	if directory == "" {
		directory, _ = os.Getwd()
	}

	// config.yml file
	fmt.Println()
	util.CreateFile(content.DefaultFilesConfigYAMLName, directory, "", false)

	// override folder
	util.CreateFolder(content.DefaultFilesOverrideFolderName, directory)

	overrideTree := fmt.Sprintf(content.DefaultFilesOverridesReadMeTree, content.DefaultFilesReadMeCodeTicks, content.DefaultFilesReadMeCodeTicks)

	overrideReadmeContent := fmt.Sprintf("%s%s%s", content.DefaultFilesOverridesReadMeHeader, overrideTree, content.DefaultFilesOverridesReadMeFooter)

	err := util.CreateFile(content.DefaultFilesReadMEName, path.Join(directory, content.DefaultFilesOverrideFolderName), overrideReadmeContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)

	}

	// services folder
	util.CreateFolder(content.DefaultFilesServicesFolder, directory)

	err = util.CreateFile(content.DefaultFilesConfigRBName, path.Join(directory, content.DefaultFilesServicesFolder), content.DefaultFilesConfigRBContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}

	servicesReadMeCode := fmt.Sprintf(content.DefaultFilesServicesReadMeCode, content.DefaultFilesReadMeCodeTicks, content.DefaultFilesReadMeCodeTicks)

	servicesReadMeContent := fmt.Sprintf("%s%s", content.DefaultFilesServicesReadMeHeader, servicesReadMeCode)

	err = util.CreateFile(content.DefaultFilesReadMEName, path.Join(directory+content.DefaultFilesServicesFolder), servicesReadMeContent, false)

	if err != nil {
		fmt.Println(err.Error())
	}

	if err == nil {
		fmt.Println(content.CmdCompositeInitSuccess)
	}
}

func genAuditContent(directory string) {
	//generate table.yaml
	err := util.CreateFile(content.DefaultFileTableYAMLName, directory, content.DefaultFilesTableYAMLContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}

	//generate suppression.yaml
	err = util.CreateFile(content.DefaultFileSuppressionYAMLName, directory, content.DefaultFileSuppressionYAMLContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}
}

func genServerContent(directory string) {
	//operational scripts dir
	util.CreateFolder(content.DefaultFilesOperationalScriptsFolder, directory)

	// generate operational readme file
	err := util.CreateFile(content.DefaultFilesReadMEName, path.Join(directory, content.DefaultFilesOperationalScriptsFolder), content.DefaultFilesOperationalReadMeContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}

	//boot scripts dir
	util.CreateFolder(content.DefaultFilesBootScriptsFolder, directory)

	//README.md
	err = util.CreateFile(content.DefaultFilesReadMEName, path.Join(directory, content.DefaultFilesBootScriptsFolder), content.DefaultFilesBootReadMeContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}

	//order.yaml
	err = util.CreateFile(content.DefaultFilesOrderYAMLName, path.Join(directory, content.DefaultFilesBootScriptsFolder), content.DefaultFilesBootOrderYAMLContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}

	//shutdown scripts dir
	util.CreateFolder(content.DefaultFilesShutdownScriptsFolder, directory)

	//README.md
	err = util.CreateFile(content.DefaultFilesReadMEName, path.Join(directory, content.DefaultFilesShutdownScriptsFolder), content.DefaultFilesShutDownReadMeContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}

	//order.yaml
	err = util.CreateFile(content.DefaultFilesOrderYAMLName, path.Join(directory, content.DefaultFilesShutdownScriptsFolder), content.DefaultFilesShutDownOrderYAMLContent, false)

	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		os.Exit(-1)
	}
}
