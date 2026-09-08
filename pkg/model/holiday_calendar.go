package model

import "time"

type HolidayCalendar struct {
	ID          int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	HolidayDate string    `gorm:"column:holiday_date;type:date;not null;uniqueIndex:UQ_HOLIDAY_DATE" json:"holiday_date"`
	HolidayName string    `gorm:"column:holiday_name;size:128;not null" json:"holiday_name"`
	IsRest      bool      `gorm:"column:is_rest;not null;default:true" json:"is_rest"`
	ConfigBy    string    `gorm:"column:config_by;size:128;not null" json:"config_by"`
	ConfigAt    time.Time `gorm:"column:config_at;not null;autoCreateTime" json:"config_at"`
	UpdatedAt   time.Time `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (HolidayCalendar) TableName() string { return "TBL_HOLIDAY_CALENDAR" }