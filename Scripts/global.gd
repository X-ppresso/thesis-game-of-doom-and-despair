extends Node

const DAY_MAX_SCORE := 100
const WRONG_DIAGNOSIS_PENALTY := 20

var week1_payment := 0
var week2_payment := 0

var week1_quota := 50000
var week2_quota := 200000

var current_day_score := DAY_MAX_SCORE
var current_day_failed := false

# --- faceless walk-in diagnosis (declared so Dialogic can interpolate them as
# {Global.fc_*} in the shared walkin_diagnose / walkin_post timelines). The day
# runner fills these from the current walk-in client's data before each
# diagnosis. fc_answer is a numeric type code (see ANSWER_*) because Dialogic
# conditions compare numbers reliably, unlike strings.
const ANSWER_MALWARE := 0
const ANSWER_BLOAT := 1
const ANSWER_SYSTEM := 2

var fc_problem := ""     # client's "what's wrong" line
var fc_cause_q := ""     # MC's follow-up question
var fc_cause := ""       # client's "how it happened" line
var fc_success := ""     # client's line after a successful repair
var fc_leave := ""       # client's line when the day is failed
var fc_answer := 0       # correct diagnosis as an ANSWER_* code

signal day_score_changed(new_score: int)
signal day_failed()

## Fills the faceless-diagnosis fields from a client's "fc" dictionary
## (see SaveManager.DAY_CONFIG). Unknown keys fall back to sensible defaults.
func set_faceless_clue(fc: Dictionary) -> void:
	fc_problem = str(fc.get("problem", ""))
	fc_cause_q = str(fc.get("cause_q", "What were you doing before it happened?"))
	fc_cause = str(fc.get("cause", ""))
	fc_success = str(fc.get("success", "Thank you!"))
	fc_leave = str(fc.get("leave", "I'll come back another time."))
	fc_answer = int(fc.get("answer", ANSWER_MALWARE))

func reset_day() -> void:
	current_day_score = DAY_MAX_SCORE
	current_day_failed = false
	day_score_changed.emit(current_day_score)

func deduct_score(amount: int) -> void:
	current_day_score = maxi(0, current_day_score - amount)
	day_score_changed.emit(current_day_score)
	if current_day_score <= 0 and not current_day_failed:
		current_day_failed = true
		day_failed.emit()

func award_week1_payment() -> void:
	week1_payment += current_day_score
