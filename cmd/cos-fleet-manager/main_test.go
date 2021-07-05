package main

import (
	"github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager/pkg/environments"
	"github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager/pkg/providers/connector"
	"github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager/pkg/server"
	"github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager/pkg/services/signalbus"
	"github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager/pkg/workers"
	. "github.com/onsi/gomega"
	"testing"
)

func TestInjections(t *testing.T) {
	RegisterTestingT(t)

	env, err := environments.New(environments.DevelopmentEnv, connector.ConfigProviders(false))
	Expect(err).To(BeNil())
	err = env.CreateServices()
	Expect(err).To(BeNil())

	var bootList []environments.BootService
	env.MustResolve(&bootList)
	Expect(len(bootList)).To(Equal(5))

	_, ok := bootList[0].(signalbus.SignalBus)
	Expect(ok).To(Equal(true))
	_, ok = bootList[1].(*server.ApiServer)
	Expect(ok).To(Equal(true))
	_, ok = bootList[2].(*server.MetricsServer)
	Expect(ok).To(Equal(true))
	_, ok = bootList[3].(*server.HealthCheckServer)
	Expect(ok).To(Equal(true))
	_, ok = bootList[4].(*workers.LeaderElectionManager)
	Expect(ok).To(Equal(true))

	var workerList []workers.Worker
	env.MustResolve(&workerList)
	Expect(len(workerList)).To(Equal(1))

}
