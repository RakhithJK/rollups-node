package main

// #cgo CFLAGS: -I./
// #cgo LDFLAGS: -L./ -lcartesi
// #include "empty.cpp"
// #include "machine-c-api.h"
import "C"
import (
	"errors"
	"fmt"
)

// ------------------------------------------------------------------------------------------------

type BreakReason struct {
	inner C.CM_BREAK_REASON
}

func (breakReason BreakReason) String() string {
	switch breakReason.inner {
	case C.CM_BREAK_REASON_FAILED:
		return "failed"
	case C.CM_BREAK_REASON_HALTED:
		return "halted"
	case C.CM_BREAK_REASON_YIELDED_MANUALLY:
		return "yielded manually"
	case C.CM_BREAK_REASON_YIELDED_AUTOMATICALLY:
		return "yielded automatically"
	case C.CM_BREAK_REASON_REACHED_TARGET_MCYCLE:
		return "reached target mcycle"
	default:
		panic("invalid break reason")
	}
}

// ------------------------------------------------------------------------------------------------

type Machine struct {
	inner *C.cm_machine
}

func New() (*Machine, error) {
	var mac Machine

	var cmerr *C.char
	var code C.int

	var machine_config *C.cm_machine_config
	code = C.cm_get_default_config(&machine_config, nil)
	if err := check(code, cmerr); err != nil {
		return &mac, err
	}
	machine_config.ram.length = 65536 // TODO: per docs, should not be doing this
	defer C.cm_delete_machine_config(machine_config)

	var runtime_config C.cm_machine_runtime_config
	// TODO defer_delete_machine_runtime_config

	var machine *C.cm_machine

	code = C.cm_create_machine(machine_config, &runtime_config, &machine, &cmerr)
	if err := check(code, cmerr); err != nil {
		return &mac, err
	}

	mac.inner = machine
	return &mac, nil
}

func (machine *Machine) Run(cycles int) (BreakReason, error) {
	var breakReason BreakReason

	var cmBreakReason C.CM_BREAK_REASON
	var err *C.char // TODO: should I deallocate this?

	code := C.cm_machine_run(machine.inner, C.ulong(cycles), &cmBreakReason, &err)
	if err := check(code, err); err != nil {
		return breakReason, err
	}

	breakReason.inner = cmBreakReason
	return breakReason, nil
}

func (machine *Machine) Delete() {
	C.cm_delete_machine(machine.inner) // TODO: difference between destroy and delete machine
}

// ------------------------------------------------------------------------------------------------

func main() {
	machine, err := New()
	if err != nil {
		panic(err)
	}
	defer machine.Delete()

	breakReason, err := machine.Run(1000000)
	if err != nil {
		panic(err)
	}
	fmt.Println(breakReason)
}

// ------------------------------------------------------------------------------------------------

func check(code C.int, err *C.char) error {
	if code != 0 {
		// TODO: is GoString leaking memory here?
		return errors.New(fmt.Sprintf("cartesi-machine error %d: %s\n", code, C.GoString(err)))
	} else {
		return nil
	}
}
