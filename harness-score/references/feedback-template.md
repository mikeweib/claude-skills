# Harness 工程评分反馈模板

当 `harness-score` 技能出现以下问题时，使用此模板记录反馈：

- 评分与项目实际 harness 配置严重不符
- 某个类别评分失准（未检测到已有配置或误判缺失）
- 审计引擎执行异常或版本不兼容
- 改进建议不可操作或不适用于项目类型

---

## 模板

### 基本信息

- **日期:** YYYY-MM-DD
- **会话 ID:** （auto-memory 的 originSessionId）
- **项目模式:** consumer / repo
- **ECC 版本:** （如有）

### 错误信息

- **错误类型:** 评分失准 / 引擎异常 / 建议不当 / 版本兼容
- **涉及类别:** Tool Coverage / Context Efficiency / Quality Gates / Memory Persistence / Eval Coverage / Security Guardrails / Cost Efficiency
- **严重程度:** 高（等级错误）/ 中（单项评分失准）/ 低（改进建议不精确）

### 上下文

- **输入情况:** 评分了什么项目，项目已有的 harness 配置情况
- **技能实际输出:** 总分、等级、具体扣分类别
- **期望输出:** 应该的分数、等级

### 根因分析

- **是哪个检查规则导致了问题:** 引用 SKILL.md 的类别/节
- **为什么规则在当前场景下不适用:**

### 建议修复

- **修复方式:** 调整评分权重 / 修改检测逻辑 / 更新 ECC 版本适配 / 修改等级阈值
- **建议变更:** 具体的参数或规则修改建议（可选）
