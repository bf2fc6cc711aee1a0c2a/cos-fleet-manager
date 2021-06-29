# Contributing

## Definition of Done
* All acceptance criteria specified in JIRA are met
    * Acceptance criteria to include:
        * Required feature functionality
        * Required tests - unit, integration, manual testcases (if relevant)
        * Required documentation
        * Required metrics, monitoring dashboards and alerts
        * Required Standard Operating Procedures (SOPs)
* CI and all relevant tests are passing
* Changes have been verified by one additional reviewer against:
    * each required environment
    * each supported upgrade path
* If the changes could have an impact on the clients (either UI or CLI), a JIRA should be created for making the required changes on the client side and acknowledged by one of the client side team members.    
* PR has been merged


## Project Source
Fork cos-fleet-manager to your own Github repository: https://github.com/bf2fc6cc711aee1a0c2a/cos-fleet-manager/fork

## Set up Git Hooks
Run the following command to set up git hooks for the project. 

```
make setup/git/hooks
```

The following git hooks are currently available:
- **pre-commit**:
  - This runs checks to ensure that the staged `.go` files passes formatting and standard checks using gofmt and go vet.

## Debugging
### VS Code
Set the following configuration in your **Launch.json** file.
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Cos Fleet Manager API",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}/cmd/cos-fleet-manager/main.go",
            "env": {
                "OCM_ENV": "integration"
            },
            "args": ["serve"]
        }
    ]
}
```

## Testing

