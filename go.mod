module github.com/bf2fc6cc711aee1a0c2a/cos-fleet-manager

go 1.15

require (
	github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager v0.0.0-20210630132855-643a926523af
	github.com/golang/glog v0.0.0-20160126235308-23def4e6c14b
	github.com/onsi/gomega v1.10.1
	github.com/spf13/cobra v1.1.1
)

// uncomment if you want to build against a locally modified version of the kas-fleet-manager
// replace github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager => ../kas-fleet-manager
