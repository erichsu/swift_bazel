package spdump

import (
	"encoding/json"
	"fmt"
)

// The JSON formats described in this file are for the swift package dump-package JSON output.

// NewManifestFromJSON creates a manifest from package dump JSON.
func NewManifestFromJSON(bytes []byte) (*Manifest, error) {
	var manifest Manifest
	err := json.Unmarshal(bytes, &manifest)
	fmt.Printf("NewManifestFromJSON\n%v\n", manifest)
	if err != nil {
		return nil, err
	}
	return &manifest, nil
}

// Manifest

// A Manifest represents a Swift manifest as serialized by `swift package dump-package`.
type Manifest struct {
	Name         string
	Dependencies []Dependency
	Platforms    []Platform
	Products     []Product
	Targets      Targets
}
