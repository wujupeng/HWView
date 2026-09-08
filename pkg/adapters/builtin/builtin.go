package builtin

import (
	"github.com/hwview/hwview/pkg/adapters"
	"github.com/hwview/hwview/pkg/adapters/bmw"
	"github.com/hwview/hwview/pkg/adapters/generic"
	"github.com/hwview/hwview/pkg/adapters/huawei102"
	"github.com/hwview/hwview/pkg/adapters/magna"
	"github.com/hwview/hwview/pkg/adapters/schaeffler"
)

func RegisterBuiltins(reg *adapters.Registry) {
	reg.Register(huawei102.NewAdapter())
	reg.Register(huawei102.NewLineAdapter())
	reg.Register(bmw.NewAdapter())
	reg.Register(schaeffler.NewAdapter())
	reg.Register(magna.NewAdapter())
	reg.Register(generic.NewAdapter())
}
