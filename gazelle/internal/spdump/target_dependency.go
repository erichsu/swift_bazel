package spdump

import (
	"encoding/json"
	"fmt"
	"runtime"

	"github.com/cgrindel/swift_bazel/gazelle/internal/jsonutils"
)

// A TargetDependency represents a reference to a target's dependency.
type TargetDependency struct {
	Product *ProductReference
	ByName  *ByNameReference
	Target  *TargetReference
}

// GH148: Confirm whether targets that depend upon a library product import the product name or one
// of the modules referenced by the product.

// ImportName returns the name used to import the dependency.
func (td *TargetDependency) ImportName() string {
	if td.Product != nil {
		return td.Product.ProductName
	} else if td.ByName != nil {
		return td.ByName.Name
	}
	return ""
}

// ProductReference

// A ProductReference encapsulates a reference to a Swift product.
type ProductReference struct {
	ProductName    string
	DependencyName string
}

func (pr *ProductReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err = json.Unmarshal(b, &raw); err != nil {
		return err
	}

	fmt.Println(runtime.Caller(0))
	stackSlice := make([]byte, 512)
	s := runtime.Stack(stackSlice, false)
	fmt.Printf("\n%s", stackSlice[0:s])

	fmt.Printf("[ProductReference] target_dependency.go/ProductReference.UnmarshalJSON\n")
	fmt.Printf("[ProductReference] jsonutils.StringAtIndex(v, 0)\nv=%v\n\n", raw)
	if pr.ProductName, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	fmt.Printf("[ProductReference] jsonutils.StringAtIndex(v, 1)\nv=%v\n\n", raw)
	if pr.DependencyName, err = jsonutils.StringAtIndex(raw, 1); err != nil {
		return err
	}
	return nil
}

// UniqKey returns a string that can be used as a map key for the product.
func (pr *ProductReference) UniqKey() string {
	return fmt.Sprintf("%s-%s", pr.DependencyName, pr.ProductName)
}

// ByNameReference

// A ByNameReference represents a byName reference. It can be a product name or a target name.
type ByNameReference struct {
	// Product name or target name
	Name string
}

func (bnr *ByNameReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err = json.Unmarshal(b, &raw); err != nil {
		return err
	}
	fmt.Printf("[ByNameReference] target_dependency.go/ByNameReference.UnmarshalJSON\n")
	fmt.Printf("[ByNameReference] jsonutils.StringAtIndex(v, 0)\nv=%v\n\n", raw)
	if bnr.Name, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	return nil
}

// TargetReference

// A TargetReference represents a reference to a Swift target.
type TargetReference struct {
	TargetName string
}

func (tr *TargetReference) UnmarshalJSON(b []byte) error {
	var err error
	var raw []any
	if err = json.Unmarshal(b, &raw); err != nil {
		return err
	}
	fmt.Printf("[TargetReference] target_dependency.go/TargetReference.UnmarshalJSON\n")
	if tr.TargetName, err = jsonutils.StringAtIndex(raw, 0); err != nil {
		return err
	}
	return nil
}
