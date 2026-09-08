package audit

import (
	"context"
	"encoding/json"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

type Service struct {
	db *gorm.DB
}

func NewService(db *gorm.DB) *Service {
	return &Service{db: db}
}

func (s *Service) Record(ctx context.Context, actor, action, targetType, targetID string, change interface{}, sudoUsed bool) error {
	var changeJSON string
	if change != nil {
		b, err := json.Marshal(change)
		if err != nil {
			return err
		}
		changeJSON = string(b)
	}
	entry := &model.AuditLog{
		Actor:      actor,
		Action:     action,
		TargetType: targetType,
		TargetID:   targetID,
		Change:     changeJSON,
		SudoUsed:   sudoUsed,
	}
	return s.db.WithContext(ctx).Create(entry).Error
}
