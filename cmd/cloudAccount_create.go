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
	"fmt"
	"io"
	"time"

	"github.com/CloudCoreo/cli/pkg/aws"

	"github.com/CloudCoreo/cli/client"

	"github.com/CloudCoreo/cli/cmd/content"
	"github.com/CloudCoreo/cli/cmd/util"
	"github.com/CloudCoreo/cli/pkg/command"
	"github.com/CloudCoreo/cli/pkg/coreo"
	"github.com/spf13/cobra"
)

type cloudCreateCmd struct {
	out            io.Writer
	client         command.Interface
	cloud          command.CloudProvider
	resourceName   string
	roleName       string
	externalID     string
	roleArn        string
	awsProfile     string
	awsProfilePath string
	policy         string
	isDraft        bool
	userName       string
	email          string
	environment    string
	awsRoleArn     string
	awsExternalID  string
	provider       string
	keyValue       string
	applicationID  string
	directoryID    string
	subscriptionID string
	tags           string
}

func newCloudCreateCmd(client command.Interface, out io.Writer) *cobra.Command {
	cloudCreate := &cloudCreateCmd{
		out:    out,
		client: client,
	}

	cmd := &cobra.Command{
		Use:     content.CmdAddUse,
		Short:   content.CmdCloudAddShort,
		Long:    content.CmdCloudAddLong,
		Example: content.CmdCloudAddExample,
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := util.CheckProviderFlag(cloudCreate.provider); err != nil {
				return err
			}
			if cloudCreate.provider == "AWS" {
				if err := util.CheckCloudAddFlagsForAWS(cloudCreate.externalID, cloudCreate.roleArn, cloudCreate.roleName, cloudCreate.environment); err != nil {
					return err
				}
			} else {
				if err := util.CheckCloudAddFlagsForAzure(cloudCreate.keyValue, cloudCreate.applicationID, cloudCreate.directoryID, cloudCreate.subscriptionID, cloudCreate.environment); err != nil {
					return err
				}
			}

			if cloudCreate.client == nil {
				cloudCreate.client = coreo.NewClient(
					coreo.Host(apiEndpoint),
					coreo.RefreshToken(key))
			}

			if cloudCreate.cloud == nil {
				newServiceInput := &aws.NewServiceInput{
					AwsProfile:     cloudCreate.awsProfile,
					AwsProfilePath: cloudCreate.awsProfilePath,
				}
				cloudCreate.cloud = aws.NewService(newServiceInput)
			}

			return cloudCreate.run()
		},
	}

	f := cmd.Flags()

	f.StringVarP(&cloudCreate.resourceName, content.CmdFlagNameLong, content.CmdFlagNameShort, "", content.CmdFlagNameDescription)
	f.StringVarP(&cloudCreate.roleName, content.CmdFlagRoleName, "", "", content.CmdFlagRoleNameDescription)
	f.StringVarP(&cloudCreate.roleArn, content.CmdFlagRoleArn, "", "", content.CmdFlagRoleArnDescription)
	f.StringVarP(&cloudCreate.externalID, content.CmdFlagRoleExternalID, "", "", content.CmdFlagRoleExternalIDDescription)
	f.StringVarP(&cloudCreate.awsProfile, content.CmdFlagAwsProfile, "", "", content.CmdFlagAwsProfileDescription)
	f.StringVarP(&cloudCreate.awsProfilePath, content.CmdFlagAwsProfilePath, "", "", content.CmdFlagAwsProfilePathDescription)
	f.StringVarP(&cloudCreate.policy, content.CmdFlagAwsPolicy, "", content.CmdFlagAwsPolicyDefault, content.CmdFlagAwsPolicyDescription)
	f.BoolVarP(&cloudCreate.isDraft, content.CmdFlagIsDraft, "", false, content.CmdFlagIsDraftDescription)
	f.StringVarP(&cloudCreate.email, content.CmdFlagEmail, "", "", content.CmdFlagEmailDescription)
	f.StringVarP(&cloudCreate.userName, content.CmdFlagUserName, "", "", content.CmdFlagUserNameDescription)
	f.StringVarP(&cloudCreate.environment, content.CmdFlagEnvironmentLong, content.CmdFlagEnvironmentShort, "", content.CmdFlagEnvironmentDescription)
	f.StringVarP(&cloudCreate.provider, content.CmdFlagProvider, "", "AWS", content.CmdFlagProviderDescription)
	f.StringVarP(&cloudCreate.keyValue, content.CmdFlagKeyValue, "", "", content.CmdFlagKeyValueDescription)
	f.StringVarP(&cloudCreate.applicationID, content.CmdFlagApplicationID, "", "", content.CmdFlagApplicationIDDescription)
	f.StringVarP(&cloudCreate.directoryID, content.CmdFlagDirectoryID, "", "", content.CmdFlagDirectoryIDDescription)
	f.StringVarP(&cloudCreate.subscriptionID, content.CmdFlagSubscriptionID, "", "", content.CmdFlagSubscriptionIDDescription)
	f.StringVarP(&cloudCreate.tags, content.CmdFlagTags, "", "", content.CmdFlagTagsDescription)

	return cmd
}

func (t *cloudCreateCmd) run() error {
	input := &client.CreateCloudAccountInput{
		CloudName:      t.resourceName,
		RoleName:       t.roleName,
		ExternalID:     t.externalID,
		RoleArn:        t.roleArn,
		Policy:         t.policy,
		IsDraft:        t.isDraft,
		Email:          t.email,
		UserName:       t.userName,
		Environment:    t.environment,
		Provider:       t.provider,
		KeyValue:       t.keyValue,
		ApplicationID:  t.applicationID,
		DirectoryID:    t.directoryID,
		SubscriptionID: t.subscriptionID,
		Tags:           t.tags,
	}
	if t.roleName != "" {
		info, err := t.client.GetRoleCreationInfo(input)
		if err != nil {
			return err
		}
		arn, externalID, err := t.cloud.CreateNewRole(info)
		time.Sleep(10 * time.Second)
		if err != nil {
			return err
		}

		input.RoleArn = arn
		input.ExternalID = externalID
	}

	cloud, err := t.client.CreateCloudAccount(input)
	if err != nil {
		if t.roleName != "" {
			fmt.Println("Cloud account creation failed! Will delete created role.")
			t.cloud.DeleteRole(t.roleName)
		}
		return err
	}

	util.PrintResult(
		t.out,
		cloud,
		[]string{"ID", "Name", "Tags"},
		map[string]string{
			"ID":   "Cloud Account ID",
			"Name": "Cloud Account Name",
			"Tags": "Tags",
		},
		jsonFormat,
		verbose)

	return nil
}
