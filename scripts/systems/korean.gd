class_name Korean
## Korean particle helpers so text reads naturally with any player name.
##     Korean.eul("국밥") -> "국밥을",  Korean.eul("커피") -> "커피를"


static func has_batchim(word: String) -> bool:
	if word.is_empty():
		return false
	var code := word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return false
	return (code - 0xAC00) % 28 != 0


static func eul(word: String) -> String:
	return word + ("을" if has_batchim(word) else "를")


static func i_ga(word: String) -> String:
	return word + ("이" if has_batchim(word) else "가")


static func eun(word: String) -> String:
	return word + ("은" if has_batchim(word) else "는")


## 로/으로: "학교로", "주무관으로", "서울로" (ㄹ 받침은 "로").
static func ro(word: String) -> String:
	if word.is_empty():
		return word
	var code := word.unicode_at(word.length() - 1)
	var no_batchim := not has_batchim(word)
	var rieul := code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 == 8
	return word + ("로" if no_batchim or rieul else "으로")


static func wa(word: String) -> String:
	return word + ("과" if has_batchim(word) else "와")


## "1000" -> "1,000"
static func comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
