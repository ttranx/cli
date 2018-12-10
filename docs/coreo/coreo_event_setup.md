## coreo event setup

Setup event stream

### Synopsis

Run this command to setup event stream. It will create a CloudFormation stack with an event rule and SNS topic. You will need to run this script for each cloud account. Make sure your aws credentials have been configured before run this command.

```
coreo event setup [flags]
```

### Examples

```
  coreo event setup
  coreo event setup --aws-profile YOUR_AWS_PROFILE
```

### Options

```
      --aws-profile string        Aws shared credential file. If empty default provider chain will be used to look for credentials with the following order.
                                    1. Environment variables.
                                    2. Shared credentials file.
                                    3. If your application is running on an Amazon EC2 instance, IAM role for Amazon EC2.
      --aws-profile-path string   The file path of aws profile. If empty will look for AWS_SHARED_CREDENTIALS_FILE env variable. If the env value is empty will default to current user's home directory.
                                    Linux/OSX: "$HOME/.aws/credentials"
                                    Windows:   "%USERPROFILE%\.aws\credentials"
      --cloud-id string           Coreo cloud id
  -h, --help                      help for setup
```

### Options inherited from parent commands

```
      --api-key string      Coreo API Key (default "None")
      --api-secret string   Coreo API Secret (default "None")
      --endpoint string     Coreo API endpoint. Overrides $CC_API_ENDPOINT. (default "https://app.cloudcoreo.com/api")
      --home string         Location of your Coreo config. Overrides $COREO_HOME. (default "/Users/Jiangz/.cloudcoreo")
      --json                Output in json format
      --profile string      Coreo profile to use. Overrides $COREO_PROFILE. (default "default")
      --team-id string      Coreo team id (default "None")
      --verbose             Enable verbose output
```

### SEE ALSO

* [coreo event](coreo_event.md)	 - Manage event stream

###### Auto generated by spf13/cobra on 15-Nov-2018