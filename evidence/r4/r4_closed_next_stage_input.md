# EV1-R4 结项 — 下一阶段输入包

> 生成日期：2026-09-08
> EV1-R4 状态：🟢 FINAL PASS / CLOSED
> Git 基线：commit `1342cd2`
> 性质：**下一阶段输入定义，不含编码。进入编码须大G项目经理明确授权。**

---

## 1. EV1 已关闭 Gate

| Gate | 状态 | 关闭日期 |
|------|------|---------|
| EV1-R1 Real Collection | 🟢 PASS / CLOSED | 2026-09-08 |
| EV1-R2 Business Quantity Semantics | 🟢 PASS / CLOSED | 2026-09-08 |
| EV1-R3 Production Source Discovery | 🟢 PASS / CLOSED | 2026-09-08 |
| EV1-R4 Coding + Data Semantic Correction | 🟢 FINAL PASS / CLOSED | 2026-09-08 |

---

## 2. 冻结的架构边界（下一阶段不得违反）

### 2.1 Production Truth 架构

```
TBL_PRODUCTION_RECORD → Reference only（标签补打 / Source Data）
    ❌ 不进入 Production Truth

TBL_DAILY_PRODUCTION_PLAN → Production Truth
    ├── Dashboard（SUM(carton_count) + SUM(actual_quantity)）
    └── Report（10-row matrix, row6=row2+row3+row5）
```

### 2.2 冻结公式

| 公式 | 状态 |
|------|------|
| actual_quantity = carton_count × units_per_carton + loose_quantity | FROZEN |
| row6 = row2 + row3 + row5（row4=TARGET 不参与） | FROZEN |
| Production Quantity（人工录入，非源系统自动推导） | FROZEN |
| Carton Specification 三维模型（product + line + date） | FROZEN |

### 2.3 冻结结论

- Jili `/Cron/Jili/lists/` = 标签补打候选数据源，**NOT AUTHORIZED** 作为生产数量源
- 若要把 Jili 作为生产数量 Fallback，须单独建立 JILI-PRODUCTION-SOURCE-DISCOVERY 流程

---

## 3. 非阻塞遗留项（可作为下一阶段输入）

| # | 遗留项 | 当前状态 | 建议阶段 |
|---|--------|---------|---------|
| 1 | 审计 actor 固定为 "admin"（单管理员模式） | 非阻塞 | EV2 多用户/角色 |
| 2 | 前端登录密钥存 localStorage | 非阻塞（单管理员可接受） | EV2 会话/token |
| 3 | 多日累计列含历史测试数据 | 非阻塞 | 生产切换前清库 |
| 4 | Source semantic ambiguity（quantity=17 与 carton_count=17 数值巧合） | 已声明保留 | 业务人员确认 |
| 5 | HW102-COPY→HW102 数据修正 | 已审计留痕 | 生产环境数据治理 |
| 6 | Dashboard first/last_production_at 仍从 TBL_PRODUCTION_RECORD 聚合 | 非阻塞（时间戳元数据） | 可选优化 |

---

## 4. 下一阶段进入流程

```
Requirement（需求定义）
    ↓
Design（设计）
    ↓
Task Design（任务设计）
    ↓
PM Authorization（大G项目经理授权）
    ↓
Coding（编码）
    ↓
Test → Deploy → E2E → Evidence
    ↓
Gate Review
```

**华为云开发团队不得自行跨 Gate 进入编码。**

---

## 5. 当前系统状态快照

| 项目 | 值 |
|------|-----|
| 服务器 | 192.168.2.110 |
| 服务 | hwview-server (systemd, active) |
| 二进制 | /opt/hwview/bin/hwview-server (35.7MB) |
| 数据库 | /opt/hwview/data/hwview.db (SQLite) |
| 认证 | auth.enabled=true, admin_key=hwview-shadow-deploy |
| 前端 | /var/www/hwview (nginx 80, SPA) |
| API | /api/ 反代 127.0.0.1:8080 |
| Git 基线 | 1342cd2 (master) |

### Dashboard 验证状态

| 日期 | box_count | piece_count | 数据源 |
|------|-----------|-------------|--------|
| 2026-09-06 | 66 | 2000 | TBL_DAILY_PRODUCTION_PLAN |
| 2026-09-07 | 27 | 824 | TBL_DAILY_PRODUCTION_PLAN |
| 2026-09-08 | 17 | 519 | TBL_DAILY_PRODUCTION_PLAN |

### R4 报表验证状态

| 日期 | row2 | row3 | row5 | row6 | 公式 |
|------|------|------|------|------|------|
| 2026-09-06 | 1500 | 500 | 0 | 2000 | 1500+500+0=2000 ✅ |
| 2026-09-07 | 305 | 0 | 519 | 824 | 305+0+519=824 ✅ |
| 2026-09-08 | 0 | 0 | 519 | 519 | 0+0+519=519 ✅ |

---

## 6. Evidence 归档清单

| 文件 | 说明 |
|------|------|
| evidence/r4/r4_evidence_summary.md | R4 验收摘要（已更新至 FINAL PASS） |
| evidence/r4/r4_data_semantic_02_final_evidence.md | R4-DATA-SEMANTIC-02 Evidence Closure（10项） |
| evidence/r4/r4_data_semantic_02_coding_evidence.md | R4-DATA-SEMANTIC-02 Coding Evidence |
| evidence/r4/source_semantic_evidence_chain.md | Source Semantic 证据链 |
| evidence/r4/r4_data_semantic_01_report.md | R4-DATA-SEMANTIC-01 根因报告 |
| evidence/r4/r4_data_semantic_02_task_design.md | R4-DATA-SEMANTIC-02 Task/Design |
| deploy/fix_line_code.sh | HW102-COPY→HW102 数据修正脚本（审计留痕） |