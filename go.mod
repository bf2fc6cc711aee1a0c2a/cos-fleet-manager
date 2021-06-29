module github.com/bf2fc6cc711aee1a0c2a/cos-fleet-manager

go 1.15

require (
	github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager v0.0.0-20210629164340-7c04f8841906
	github.com/goava/di v1.10.0
	github.com/golang/glog v0.0.0-20160126235308-23def4e6c14b
	github.com/onsi/gomega v1.10.1
	github.com/spf13/cobra v1.1.1
)

replace github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager v0.0.0-20210629164340-7c04f8841906 => ../kas-fleet-manager
