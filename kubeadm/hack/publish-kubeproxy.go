package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/Masterminds/semver"
	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/remote"
)

const (
	supportedVersions = ">= 1.17.0"
)

func dockerBuild(v *semver.Version, dockerfilePath string) error {
	cmd := exec.Command("docker", "build", "--pull",
		fmt.Sprintf("--build-arg=k8sVersion=v%s", v.String()),
		fmt.Sprintf("--tag=sigwindowstools/kube-proxy:v%s", v.String()),
		dockerfilePath,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func dockerPush() error {
	cmd := exec.Command("docker", "push", "sigwindowstools/kube-proxy")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	dockerfilePath := os.Args[1]
	constraint, err := semver.NewConstraint(supportedVersions)
	if err != nil {
		log.Fatalf("err parsing %s: %v", supportedVersions, err)
	}

	repo, err := name.NewRepository("k8s.gcr.io/kube-proxy")
	if err != nil {
		log.Fatalf("err parsing %v", err)
	}
	tags, err := remote.List(repo)
	if err != nil {
		log.Fatalf("err fetching tags %v", err)
	}
	for _, t := range tags {
		v, err := semver.NewVersion(t)
		if err != nil {
			log.Printf("err parsing %s, %v", t, err)
		}
		if constraint.Check(v) {
			if err := dockerBuild(v, dockerfilePath); err != nil {
				log.Fatalf("Error building docker image for %v: %v", v, err)
			}
		}
	}
	if err := dockerPush(); err != nil {
		log.Fatalf("Error pushing docker image: %v", err)
	}
}
