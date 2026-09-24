class_name SoundSynth
extends RefCounted
## Synthèse procédurale de tous les sons du jeu (aucun fichier audio requis).
## Chaque son est un AudioStreamWAV 16 bits mono. AudioManager les met en cache dans user://.
## Pour remplacer un son par un vrai fichier, déposez res://audio/<nom>.ogg (ou .wav / .mp3).

const NAMES: Array[String] = [
	"step_wood_1", "step_wood_2", "step_wood_3", "step_stone_1", "step_stone_2",
	"step_monster_1", "step_monster_2", "breath_monster", "monster_scream", "monster_growl",
	"heartbeat", "door_open", "door_close", "door_slam", "door_bash", "door_locked",
	"pickup", "key_pickup", "paper", "flash_on", "flash_off", "battery", "lever", "fuse",
	"power_on", "elevator", "safe_beep", "safe_error", "safe_open", "match", "candle_out",
	"music_box", "whisper_1", "whisper_2", "giggle", "sting_high", "sting_low", "scream",
	"bang", "knock", "glass", "thunder", "wind_loop", "drone_loop", "tension_loop",
	"chase_loop", "clock_tick", "clock_chime", "drip", "fire_loop", "buzz_loop",
	"creak_1", "creak_2", "creak_3", "ui_hover", "ui_click", "capture", "victory",
	"breath_player", "hide", "footsteps_above", "whoosh", "static",
]

const LOOPS: Array[String] = [
	"breath_monster", "wind_loop", "drone_loop", "tension_loop", "chase_loop",
	"clock_tick", "fire_loop", "buzz_loop", "breath_player",
]

static var _sr: int = 22050
static var _table: PackedFloat32Array = PackedFloat32Array()
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func generate(snd: String) -> AudioStreamWAV:
	_rng.seed = hash(snd)
	_ensure_table()
	_sr = 22050
	var buf := PackedFloat32Array()
	match snd:
		"step_wood_1":
			buf = _step_wood(0)
		"step_wood_2":
			buf = _step_wood(1)
		"step_wood_3":
			buf = _step_wood(2)
		"step_stone_1":
			buf = _step_stone(0)
		"step_stone_2":
			buf = _step_stone(1)
		"step_monster_1":
			buf = _step_monster(0)
		"step_monster_2":
			buf = _step_monster(1)
		"breath_monster":
			buf = _breath_monster()
		"monster_scream":
			buf = _monster_scream()
		"monster_growl":
			buf = _monster_growl()
		"heartbeat":
			buf = _heartbeat()
		"door_open":
			buf = _door_open(1.1, 1.0)
		"door_close":
			buf = _door_close()
		"door_slam":
			buf = _door_slam()
		"door_bash":
			buf = _door_bash()
		"door_locked":
			buf = _door_locked()
		"pickup":
			buf = _pickup()
		"key_pickup":
			buf = _key_pickup()
		"paper":
			buf = _paper()
		"flash_on":
			buf = _click(0.07, 3500.0, 520.0)
		"flash_off":
			buf = _click(0.07, 2500.0, 380.0)
		"battery":
			buf = _battery()
		"lever":
			buf = _lever()
		"fuse":
			buf = _fuse()
		"power_on":
			buf = _power_on()
		"elevator":
			buf = _elevator()
		"safe_beep":
			buf = _beep(0.09, 1400.0, 1)
		"safe_error":
			buf = _beep(0.55, 300.0, 2)
		"safe_open":
			buf = _safe_open()
		"match":
			buf = _match()
		"candle_out":
			buf = _candle_out()
		"music_box":
			buf = _music_box()
		"whisper_1":
			buf = _whisper(1.9)
		"whisper_2":
			buf = _whisper(1.5)
		"giggle":
			buf = _giggle()
		"sting_high":
			buf = _sting_high()
		"sting_low":
			buf = _sting_low()
		"scream":
			buf = _scream(1.4)
		"bang":
			buf = _bang()
		"knock":
			buf = _knock()
		"glass":
			buf = _glass()
		"thunder":
			buf = _thunder()
		"wind_loop":
			buf = _wind_loop()
		"drone_loop":
			buf = _drone_loop()
		"tension_loop":
			buf = _tension_loop()
		"chase_loop":
			buf = _chase_loop()
		"clock_tick":
			buf = _clock_tick()
		"clock_chime":
			buf = _clock_chime()
		"drip":
			buf = _drip()
		"fire_loop":
			buf = _fire_loop()
		"buzz_loop":
			buf = _buzz_loop()
		"creak_1":
			buf = _creak(1.1, 22.0, 520.0)
		"creak_2":
			buf = _creak(1.4, 30.0, 680.0)
		"creak_3":
			buf = _creak(0.9, 18.0, 430.0)
		"ui_hover":
			buf = _click(0.04, 3000.0, 900.0)
		"ui_click":
			buf = _click(0.09, 1800.0, 300.0)
		"capture":
			buf = _capture()
		"victory":
			buf = _victory()
		"breath_player":
			buf = _breath_player()
		"hide":
			buf = _hide()
		"footsteps_above":
			buf = _footsteps_above()
		"whoosh":
			buf = _whoosh()
		"static":
			buf = _static()
		_:
			buf = _click(0.05, 1000.0, 200.0)
	return _to_wav(buf, snd in LOOPS)


# ============================================================ outils DSP

static func _ensure_table() -> void:
	if _table.size() > 0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = 1234567
	_table.resize(131072)
	for i: int in range(131072):
		_table[i] = r.randf() * 2.0 - 1.0


static func _len(sec: float) -> int:
	return maxi(1, int(sec * float(_sr)))


static func _silence(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(_len(sec))
	return b


## Bruit blanc (copie rapide depuis une table pré-calculée).
static func _noise(sec: float) -> PackedFloat32Array:
	var n := _len(sec)
	var out := PackedFloat32Array()
	var start := _rng.randi_range(0, 131071)
	while out.size() < n:
		var take := mini(n - out.size(), 131072 - start)
		out.append_array(_table.slice(start, start + take))
		start = 0
	return out


static func _lowpass(b: PackedFloat32Array, fc: float) -> void:
	var a := 1.0 - exp(-TAU * fc / float(_sr))
	var y := 0.0
	for i: int in range(b.size()):
		y += a * (b[i] - y)
		b[i] = y


static func _highpass(b: PackedFloat32Array, fc: float) -> void:
	var a := 1.0 - exp(-TAU * fc / float(_sr))
	var y := 0.0
	for i: int in range(b.size()):
		var x := b[i]
		y += a * (x - y)
		b[i] = x - y


## Passe-bande biquad (RBJ, gain de crête 0 dB). f1 > 0 : balayage linéaire de f0 vers f1.
static func _bandpass(b: PackedFloat32Array, f0: float, q: float, f1: float = -1.0) -> void:
	var n := b.size()
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var nyq := float(_sr) * 0.45
	for i: int in range(n):
		if (i & 63) == 0:
			var f := f0
			if f1 > 0.0:
				f = lerpf(f0, f1, float(i) / float(n))
			f = clampf(f, 20.0, nyq)
			var w0 := TAU * f / float(_sr)
			var alpha := sin(w0) / (2.0 * q)
			var a0 := 1.0 + alpha
			b0 = alpha / a0
			b2 = -alpha / a0
			a1 = -2.0 * cos(w0) / a0
			a2 = (1.0 - alpha) / a0
		var x := b[i]
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		b[i] = y


## Enveloppe : attaque linéaire puis décroissance exponentielle (constante de temps `decay`).
static func _env(b: PackedFloat32Array, attack: float, decay: float) -> void:
	var na := _len(attack)
	var k := exp(-1.0 / (decay * float(_sr)))
	var g := 1.0
	for i: int in range(b.size()):
		if i < na:
			b[i] *= float(i) / float(na)
		else:
			g *= k
			b[i] *= g


static func _fade(b: PackedFloat32Array, fade_in: float, fade_out: float) -> void:
	var n := b.size()
	var ni := _len(fade_in)
	var no := _len(fade_out)
	for i: int in range(mini(ni, n)):
		b[i] *= float(i) / float(ni)
	for i: int in range(mini(no, n)):
		b[n - 1 - i] *= float(i) / float(no)


static func _sine_sweep(sec: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var n := _len(sec)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i: int in range(n):
		var f := lerpf(f0, f1, float(i) / float(n))
		ph += TAU * f / float(_sr)
		b[i] = sin(ph) * amp
	return b


static func _saw(sec: float, f: float, amp: float, vib_rate: float = 0.0, vib_depth: float = 0.0, glide_to: float = -1.0) -> PackedFloat32Array:
	var n := _len(sec)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := _rng.randf()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var ff := f
		if glide_to > 0.0:
			ff = lerpf(f, glide_to, float(i) / float(n))
		if vib_depth > 0.0:
			ff *= 1.0 + vib_depth * sin(TAU * vib_rate * t)
		var dt := ff / float(_sr)
		ph += dt
		ph -= floorf(ph)
		# Dent de scie à bande limitée (polyBLEP) : beaucoup moins de repliement.
		var v := ph * 2.0 - 1.0
		if ph < dt:
			var x := ph / dt
			v -= x + x - x * x - 1.0
		elif ph > 1.0 - dt:
			var x2 := (ph - 1.0) / dt
			v -= x2 * x2 + x2 + x2 + 1.0
		b[i] = v * amp
	return b


static func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at_sec: float, gain: float) -> void:
	var off := int(at_sec * float(_sr))
	var n := mini(src.size(), dst.size() - off)
	for i: int in range(maxi(n, 0)):
		dst[off + i] += src[i] * gain


static func _normalize(b: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for i: int in range(b.size()):
		var v := absf(b[i])
		if v > m:
			m = v
	var g := peak / m
	for i: int in range(b.size()):
		b[i] *= g


static func _distort(b: PackedFloat32Array, drive: float) -> void:
	for i: int in range(b.size()):
		b[i] = tanh(b[i] * drive)


static func _mul(b: PackedFloat32Array, g: float) -> void:
	for i: int in range(b.size()):
		b[i] *= g


## Rend une boucle sans raccord : le début est fondu avec la fin (xfade secondes).
static func _loopify(b: PackedFloat32Array, xfade: float) -> PackedFloat32Array:
	var nx := _len(xfade)
	var total := b.size() - nx
	var out := b.slice(0, total)
	for i: int in range(nx):
		var t := float(i) / float(nx)
		out[i] = b[i] * t + b[total + i] * (1.0 - t)
	return out


static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var n := buf.size()
	var half := (n + 1) >> 1
	var ints := PackedInt32Array()
	ints.resize(half)
	for i: int in range(half):
		var fa := buf[2 * i]
		if fa > 1.0:
			fa = 1.0
		elif fa < -1.0:
			fa = -1.0
		var fb := 0.0
		if 2 * i + 1 < n:
			fb = buf[2 * i + 1]
			if fb > 1.0:
				fb = 1.0
			elif fb < -1.0:
				fb = -1.0
		var a := int(fa * 32767.0) & 0xFFFF
		var bb := int(fb * 32767.0) & 0xFFFF
		var v := a | (bb << 16)
		if v >= 0x80000000:
			v -= 0x100000000
		ints[i] = v
	var bytes := ints.to_byte_array()
	bytes.resize(n * 2)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = _sr
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


static func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


# ============================================================ bruitages

static func _step_wood(v: int) -> PackedFloat32Array:
	var out := _silence(0.22)
	var nb := _noise(0.15)
	_bandpass(nb, 260.0 + 90.0 * float(v), 1.1)
	_env(nb, 0.002, 0.03)
	_mix(out, nb, 0.0, 1.0)
	var th := _sine_sweep(0.14, 130.0 - 10.0 * float(v), 55.0, 0.9)
	_env(th, 0.001, 0.03)
	_mix(out, th, 0.0, 0.8)
	var cl := _noise(0.02)
	_highpass(cl, 2500.0)
	_env(cl, 0.0005, 0.004)
	_mix(out, cl, 0.0, 0.25)
	if v == 2:
		var cr := _creak(0.25, 40.0, 900.0)
		_mix(out, cr, 0.02, 0.15)
	_normalize(out, 0.75)
	return out


static func _step_stone(v: int) -> PackedFloat32Array:
	var out := _silence(0.2)
	var nb := _noise(0.12)
	_bandpass(nb, 1300.0 + 300.0 * float(v), 1.4)
	_env(nb, 0.001, 0.022)
	_mix(out, nb, 0.0, 1.0)
	var th := _sine_sweep(0.1, 110.0, 60.0, 0.6)
	_env(th, 0.001, 0.02)
	_mix(out, th, 0.0, 0.6)
	var gr := _noise(0.1)
	_bandpass(gr, 3500.0, 0.8)
	_env(gr, 0.01, 0.03)
	_mix(out, gr, 0.01, 0.2)
	_normalize(out, 0.7)
	return out


static func _step_monster(v: int) -> PackedFloat32Array:
	var out := _silence(0.5)
	var th := _sine_sweep(0.35, 75.0 - 8.0 * float(v), 32.0, 1.0)
	_env(th, 0.002, 0.09)
	_mix(out, th, 0.0, 1.0)
	var nb := _noise(0.3)
	_bandpass(nb, 170.0, 0.8)
	_env(nb, 0.002, 0.07)
	_mix(out, nb, 0.0, 1.2)
	var sc := _noise(0.3)
	_bandpass(sc, 900.0 + 200.0 * float(v), 2.0, 600.0)
	_env(sc, 0.04, 0.08)
	_mix(out, sc, 0.05, 0.35)
	_distort(out, 1.6)
	_normalize(out, 0.9)
	return out


static func _breath_monster() -> PackedFloat32Array:
	_sr = 16000
	var total := 3.6
	var loop_len := 3.4
	var b := _noise(total)
	var n := b.size()
	# enveloppe inspiration / expiration
	for i: int in range(n):
		var t := fmod(float(i) / float(_sr), loop_len)
		var e := 0.0
		if t < 1.3:
			e = sin(t / 1.3 * PI) * 0.8
		elif t > 1.55 and t < 3.2:
			var u := (t - 1.55) / 1.65
			e = sin(u * PI) * (0.75 + 0.25 * sin(TAU * 38.0 * t))
		b[i] *= e
	var inhale := b.duplicate()
	_bandpass(inhale, 750.0, 2.2, 1250.0)
	var exhale := b.duplicate()
	_bandpass(exhale, 480.0, 2.0)
	var out := _silence(total)
	for i: int in range(n):
		var t := fmod(float(i) / float(_sr), loop_len)
		out[i] = inhale[i] if t < 1.45 else exhale[i] * 1.3
	var growl := _saw(total, 62.0, 0.25, 5.0, 0.03)
	_lowpass(growl, 260.0)
	for i: int in range(n):
		var t := fmod(float(i) / float(_sr), loop_len)
		if t > 1.6 and t < 3.15:
			out[i] += growl[i] * sin((t - 1.6) / 1.55 * PI)
	_normalize(out, 0.8)
	var lp := _loopify(out, 0.2)
	return lp


static func _monster_scream() -> PackedFloat32Array:
	# Cri « vocal » : trois voix en dents de scie très vibrées, filtrées par deux formants,
	# un souffle rauque, et une légère saturation.
	var dur := 2.0
	var src := _silence(dur)
	var freqs: Array[float] = [233.0, 277.0]
	for f: float in freqs:
		var v := _saw(dur, f * 1.3, 0.45, 6.5 + _rng.randf() * 2.0, 0.035, f * 0.72)
		_mix(src, v, 0.0, 1.0)
	var f1 := src.duplicate()
	_bandpass(f1, 820.0, 2.5, 620.0)
	var f2 := src.duplicate()
	_bandpass(f2, 2300.0, 3.5, 1700.0)
	var f3 := src.duplicate()
	_bandpass(f3, 3400.0, 5.0, 2800.0)
	var out := _silence(dur)
	_mix(out, f1, 0.0, 1.0)
	_mix(out, f2, 0.0, 0.8)
	_mix(out, f3, 0.0, 0.35)
	var rasp := _noise(dur)
	_bandpass(rasp, 2600.0, 1.5, 1400.0)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		rasp[i] *= 0.6 + 0.4 * sin(TAU * 38.0 * t)
	_mix(out, rasp, 0.0, 0.08)
	_normalize(out, 1.0)
	_distort(out, 1.3)
	for i: int in range(n):
		var t2 := float(i) / float(n)
		var e := minf(t2 / 0.03, 1.0) * (1.0 if t2 < 0.6 else (1.0 - t2) / 0.4)
		out[i] *= e
	_normalize(out, 0.95)
	return out


static func _monster_growl() -> PackedFloat32Array:
	var dur := 1.4
	var a := _saw(dur, 52.0, 0.5, 3.0, 0.04)
	var b := _saw(dur, 55.3, 0.5, 2.2, 0.05)
	var out := _silence(dur)
	_mix(out, a, 0.0, 1.0)
	_mix(out, b, 0.0, 1.0)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		out[i] *= 0.55 + 0.45 * sin(TAU * 11.0 * t + 2.0 * sin(TAU * 2.7 * t))
	_lowpass(out, 420.0)
	_distort(out, 2.5)
	_fade(out, 0.12, 0.4)
	_normalize(out, 0.85)
	return out


static func _heartbeat() -> PackedFloat32Array:
	var out := _silence(0.7)
	var lub := _sine_sweep(0.2, 62.0, 42.0, 1.0)
	_env(lub, 0.004, 0.05)
	_mix(out, lub, 0.0, 1.0)
	var dub := _sine_sweep(0.2, 54.0, 38.0, 1.0)
	_env(dub, 0.004, 0.06)
	_mix(out, dub, 0.2, 0.8)
	_lowpass(out, 180.0)
	_normalize(out, 0.95)
	return out


static func _creak(dur: float, rate: float, reso: float) -> PackedFloat32Array:
	var n := _len(dur)
	var imp := PackedFloat32Array()
	imp.resize(n)
	var ph := 0.0
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var f := rate * (1.0 + 0.6 * sin(t * 2.3 + 0.5) + 0.25 * sin(t * 7.1)) * (0.9 + 0.2 * _rng.randf())
		ph += f / float(_sr)
		if ph >= 1.0:
			ph -= 1.0
			imp[i] = 1.0
	var a := imp.duplicate()
	_bandpass(a, reso, 9.0)
	var b := imp.duplicate()
	_bandpass(b, reso * 2.3, 7.0)
	var out := _silence(dur)
	for i: int in range(n):
		out[i] = a[i] + b[i] * 0.6
	_fade(out, 0.05, dur * 0.3)
	_normalize(out, 0.7)
	return out


static func _door_open(dur: float, gain: float) -> PackedFloat32Array:
	var out := _silence(dur)
	var cl := _noise(0.03)
	_highpass(cl, 2500.0)
	_env(cl, 0.0005, 0.006)
	_mix(out, cl, 0.0, 0.6)
	var cr := _creak(dur - 0.05, 55.0, 780.0)
	_mix(out, cr, 0.04, 1.0)
	_normalize(out, 0.7 * gain)
	return out


static func _door_close() -> PackedFloat32Array:
	var out := _silence(0.5)
	var th := _sine_sweep(0.3, 95.0, 48.0, 1.0)
	_env(th, 0.002, 0.07)
	_mix(out, th, 0.0, 1.0)
	var nb := _noise(0.2)
	_lowpass(nb, 900.0)
	_env(nb, 0.001, 0.04)
	_mix(out, nb, 0.0, 1.2)
	var latch := _noise(0.02)
	_bandpass(latch, 3000.0, 3.0)
	_env(latch, 0.0005, 0.005)
	_mix(out, latch, 0.035, 0.8)
	_normalize(out, 0.8)
	return out


static func _door_slam() -> PackedFloat32Array:
	var out := _silence(1.1)
	var th := _sine_sweep(0.6, 75.0, 32.0, 1.0)
	_env(th, 0.001, 0.14)
	_mix(out, th, 0.0, 1.0)
	var nb := _noise(0.4)
	_lowpass(nb, 1800.0)
	_env(nb, 0.001, 0.07)
	_mix(out, nb, 0.0, 1.4)
	for k: int in range(5):
		var r := _noise(0.03)
		_bandpass(r, 2200.0 + 400.0 * float(k), 5.0)
		_env(r, 0.0005, 0.008)
		_mix(out, r, 0.06 + 0.05 * float(k) + 0.02 * _rng.randf(), 0.5 / float(k + 1))
	var tail := _noise(1.0)
	_lowpass(tail, 110.0)
	_env(tail, 0.01, 0.3)
	_mix(out, tail, 0.02, 3.0)
	_distort(out, 1.5)
	_normalize(out, 0.95)
	return out


static func _door_bash() -> PackedFloat32Array:
	var out := _silence(1.0)
	var crack := _noise(0.2)
	_env(crack, 0.0005, 0.03)
	_mix(out, crack, 0.0, 1.0)
	var th := _sine_sweep(0.5, 80.0, 35.0, 1.0)
	_env(th, 0.001, 0.12)
	_mix(out, th, 0.0, 1.2)
	var cr := _creak(0.6, 70.0, 700.0)
	_mix(out, cr, 0.15, 0.6)
	_distort(out, 1.8)
	_normalize(out, 0.95)
	return out


static func _door_locked() -> PackedFloat32Array:
	var out := _silence(0.6)
	var times: Array[float] = [0.0, 0.12, 0.23]
	for t: float in times:
		var m := _noise(0.05)
		_bandpass(m, 2600.0 + 300.0 * _rng.randf(), 4.0)
		_env(m, 0.0005, 0.012)
		_mix(out, m, t, 1.0)
		var th := _sine_sweep(0.1, 140.0, 80.0, 0.5)
		_env(th, 0.001, 0.02)
		_mix(out, th, t, 0.6)
	_normalize(out, 0.7)
	return out


static func _pickup() -> PackedFloat32Array:
	var out := _silence(0.3)
	var r := _noise(0.25)
	_bandpass(r, 2000.0, 1.0)
	_env(r, 0.005, 0.05)
	_mix(out, r, 0.0, 0.8)
	var c := _click(0.05, 2500.0, 600.0)
	_mix(out, c, 0.02, 0.6)
	_normalize(out, 0.6)
	return out


static func _metal_hit(dur: float, base: float, decay: float) -> PackedFloat32Array:
	var n := _len(dur)
	var b := PackedFloat32Array()
	b.resize(n)
	var ratios: Array[float] = [1.0, 1.59, 2.4, 3.2]
	var amps: Array[float] = [1.0, 0.6, 0.4, 0.25]
	for k: int in range(ratios.size()):
		var f := base * ratios[k]
		var w := TAU * f / float(_sr)
		var d := exp(-1.0 / ((decay / float(k + 1)) * float(_sr)))
		var g := amps[k]
		for i: int in range(n):
			b[i] += sin(w * float(i)) * g
			g *= d
	return b


static func _key_pickup() -> PackedFloat32Array:
	var out := _silence(0.8)
	_mix(out, _metal_hit(0.5, 2150.0, 0.18), 0.0, 1.0)
	_mix(out, _metal_hit(0.5, 2480.0, 0.14), 0.09, 0.7)
	_mix(out, _metal_hit(0.5, 1980.0, 0.2), 0.2, 0.6)
	_normalize(out, 0.55)
	return out


static func _paper() -> PackedFloat32Array:
	var b := _noise(0.6)
	_bandpass(b, 3500.0, 0.8)
	var n := b.size()
	var level := 0.0
	var seg := 0
	for i: int in range(n):
		if seg <= 0:
			level = _rng.randf()
			seg = _rng.randi_range(120, 600)
		seg -= 1
		b[i] *= level
	_fade(b, 0.02, 0.2)
	_normalize(b, 0.5)
	return b


static func _click(dur: float, hp: float, tone: float) -> PackedFloat32Array:
	var out := _silence(dur)
	var c := _noise(dur)
	_highpass(c, hp)
	_env(c, 0.0003, 0.004)
	_mix(out, c, 0.0, 1.0)
	var t := _sine_sweep(dur, tone, tone * 0.7, 0.6)
	_env(t, 0.0005, 0.008)
	_mix(out, t, 0.0, 1.0)
	_normalize(out, 0.6)
	return out


static func _battery() -> PackedFloat32Array:
	var out := _silence(0.55)
	_mix(out, _click(0.06, 3000.0, 700.0), 0.0, 1.0)
	var s := _noise(0.18)
	_bandpass(s, 1500.0, 1.5)
	_fade(s, 0.03, 0.05)
	_mix(out, s, 0.1, 0.4)
	_mix(out, _click(0.06, 2500.0, 500.0), 0.36, 1.0)
	_normalize(out, 0.6)
	return out


static func _lever() -> PackedFloat32Array:
	var out := _silence(0.9)
	for k: int in range(6):
		var r := _noise(0.02)
		_bandpass(r, 2000.0, 4.0)
		_env(r, 0.0005, 0.005)
		_mix(out, r, float(k) * 0.03, 0.5)
	var th := _sine_sweep(0.4, 85.0, 40.0, 1.0)
	_env(th, 0.001, 0.09)
	_mix(out, th, 0.22, 1.2)
	var nb := _noise(0.3)
	_lowpass(nb, 700.0)
	_env(nb, 0.001, 0.05)
	_mix(out, nb, 0.22, 1.0)
	_normalize(out, 0.85)
	return out


static func _fuse() -> PackedFloat32Array:
	var out := _silence(1.0)
	_mix(out, _click(0.06, 2800.0, 600.0), 0.0, 1.0)
	var z := _noise(0.5)
	_highpass(z, 1800.0)
	var n := z.size()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var sq := 1.0 if fmod(t * 120.0, 1.0) < 0.5 else 0.3
		z[i] *= sq * exp(-t / 0.15)
	_mix(out, z, 0.08, 0.7)
	var th := _sine_sweep(0.3, 90.0, 45.0, 1.0)
	_env(th, 0.001, 0.06)
	_mix(out, th, 0.5, 0.8)
	_normalize(out, 0.8)
	return out


static func _power_on() -> PackedFloat32Array:
	var dur := 2.6
	var out := _silence(dur)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var ramp := minf(t / 1.2, 1.0) * (1.0 if t < 2.0 else (dur - t) / 0.6)
		var s := sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.35 + sin(TAU * 150.0 * t) * 0.2 + sin(TAU * 250.0 * t) * 0.1
		out[i] = s * ramp
	var nz := _noise(dur)
	_bandpass(nz, 3000.0, 1.0)
	_mix(out, nz, 0.0, 0.08)
	var th := _sine_sweep(0.3, 90.0, 40.0, 1.0)
	_env(th, 0.001, 0.06)
	_mix(out, th, 0.0, 1.0)
	_normalize(out, 0.7)
	return out


static func _elevator() -> PackedFloat32Array:
	var dur := 4.2
	var out := _saw(dur, 46.0, 0.6, 1.3, 0.04)
	_lowpass(out, 300.0)
	var t := 0.1
	while t < 3.6:
		var c := _noise(0.03)
		_bandpass(c, 1700.0 + 500.0 * _rng.randf(), 5.0)
		_env(c, 0.0005, 0.008)
		_mix(out, c, t, 0.9)
		t += 0.05 + 0.08 * _rng.randf()
	var th := _sine_sweep(0.5, 80.0, 35.0, 1.0)
	_env(th, 0.001, 0.12)
	_mix(out, th, 3.7, 2.0)
	_fade(out, 0.2, 0.3)
	_normalize(out, 0.85)
	return out


static func _beep(dur: float, f: float, count: int) -> PackedFloat32Array:
	var out := _silence(dur)
	var n := out.size()
	var seg := maxi(1, int(float(n) / float(count)))
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var local := i % seg
		var on := local < int(float(seg) * 0.7)
		if on:
			out[i] = (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * 0.3
	_lowpass(out, 5000.0)
	_fade(out, 0.002, 0.01)
	return out


static func _safe_open() -> PackedFloat32Array:
	var out := _silence(1.3)
	var th := _sine_sweep(0.4, 80.0, 40.0, 1.0)
	_env(th, 0.001, 0.08)
	_mix(out, th, 0.0, 1.0)
	_mix(out, _click(0.06, 2000.0, 400.0), 0.0, 0.8)
	var cr := _creak(0.9, 35.0, 600.0)
	_mix(out, cr, 0.3, 0.7)
	_normalize(out, 0.8)
	return out


static func _match() -> PackedFloat32Array:
	var out := _silence(0.9)
	var s := _noise(0.15)
	_bandpass(s, 3000.0, 1.2)
	var n := s.size()
	for i: int in range(n):
		s[i] *= 0.4 + 0.6 * _rng.randf()
	_fade(s, 0.005, 0.03)
	_mix(out, s, 0.0, 0.8)
	var w := _noise(0.6)
	_bandpass(w, 300.0, 0.7, 1800.0)
	_fade(w, 0.08, 0.35)
	_mix(out, w, 0.12, 1.0)
	_normalize(out, 0.6)
	return out


static func _candle_out() -> PackedFloat32Array:
	var w := _noise(0.5)
	_lowpass(w, 600.0)
	_fade(w, 0.05, 0.3)
	_normalize(w, 0.5)
	return w


static func _music_box() -> PackedFloat32Array:
	_sr = 16000
	# « Au clair de la lune » en mineur, lent et désaccordé (air traditionnel, domaine public).
	var a: Array[float] = [72.0, 1.0, 72.0, 1.0, 72.0, 1.0, 74.0, 1.0, 75.0, 2.0, 74.0, 2.0, 72.0, 1.0, 75.0, 1.0, 74.0, 1.0, 74.0, 1.0, 72.0, 4.0]
	var b: Array[float] = [74.0, 1.0, 74.0, 1.0, 74.0, 1.0, 74.0, 1.0, 68.0, 2.0, 68.0, 2.0, 74.0, 1.0, 72.0, 1.0, 71.0, 1.0, 68.0, 1.0, 67.0, 4.0]
	var seq: Array[float] = []
	seq.append_array(a)
	seq.append_array(b)
	seq.append_array(a)
	var beat := 0.36
	var total_beats := 0.0
	for k: int in range(1, seq.size(), 2):
		total_beats += seq[k]
	var out := _silence(total_beats * beat + 1.5)
	var cache: Dictionary = {}
	var t := 0.2
	for k: int in range(0, seq.size(), 2):
		var m := seq[k] + 12.0
		if not cache.has(m):
			cache[m] = _tine(_midi(m) * (1.0 + (_rng.randf() - 0.5) * 0.006))
		var note: PackedFloat32Array = cache[m]
		_mix(out, note, t + (_rng.randf() - 0.5) * 0.02, 0.8)
		t += seq[k + 1] * beat * (1.0 + (_rng.randf() - 0.5) * 0.05)
	_normalize(out, 0.7)
	return out


static func _tine(f: float) -> PackedFloat32Array:
	var n := _len(1.4)
	var b := PackedFloat32Array()
	b.resize(n)
	var ratios: Array[float] = [1.0, 2.0, 3.0, 4.2]
	var amps: Array[float] = [1.0, 0.35, 0.12, 0.08]
	var decays: Array[float] = [0.55, 0.25, 0.12, 0.06]
	for k: int in range(4):
		var w := TAU * f * ratios[k] / float(_sr)
		var d := exp(-1.0 / (decays[k] * float(_sr)))
		var g := amps[k]
		for i: int in range(n):
			b[i] += sin(w * float(i)) * g
			g *= d
	return b


static func _whisper(dur: float) -> PackedFloat32Array:
	var src := _noise(dur)
	var n := src.size()
	var out := _silence(dur)
	var vowels: Array[Vector2] = [Vector2(700.0, 1200.0), Vector2(400.0, 2000.0), Vector2(300.0, 2300.0), Vector2(600.0, 1000.0), Vector2(500.0, 1700.0)]
	var t := 0.05
	while t < dur - 0.2:
		var syl := 0.12 + 0.12 * _rng.randf()
		var v: Vector2 = vowels[_rng.randi_range(0, vowels.size() - 1)]
		var seg := _noise(syl)
		var s1 := seg.duplicate()
		_bandpass(s1, v.x, 5.0)
		var s2 := seg.duplicate()
		_bandpass(s2, v.y, 6.0)
		var m := seg.size()
		for i: int in range(m):
			var e := sin(float(i) / float(m) * PI)
			seg[i] = (s1[i] + s2[i] * 0.7) * e
		_mix(out, seg, t, 1.0)
		if _rng.randf() < 0.35:
			var s := _noise(0.08)
			_highpass(s, 4500.0)
			_fade(s, 0.02, 0.04)
			_mix(out, s, t + syl, 0.25)
		t += syl + 0.02 + 0.1 * _rng.randf()
	for i: int in range(n):
		out[i] += src[i] * 0.01
	_normalize(out, 0.55)
	return out


static func _giggle() -> PackedFloat32Array:
	var out := _silence(1.5)
	var t := 0.05
	for k: int in range(6):
		var dur := 0.085
		var f0 := 760.0 - 35.0 * float(k)
		var s := _sine_sweep(dur, f0, f0 * 0.85, 1.0)
		var nz := _noise(dur)
		_bandpass(nz, 2600.0, 3.0)
		var m := s.size()
		for i: int in range(m):
			var e := sin(float(i) / float(m) * PI)
			s[i] = (s[i] + nz[i] * 0.4) * e
		_mix(out, s, t, 1.0)
		_mix(out, s, t + 0.11, 0.25)
		t += 0.12 + 0.03 * _rng.randf()
	_normalize(out, 0.5)
	return out


static func _sting_high() -> PackedFloat32Array:
	var dur := 2.3
	var out := _silence(dur)
	var freqs: Array[float] = [1046.0, 1108.7, 1480.0, 1568.0, 2093.0, 740.0]
	for f: float in freqs:
		var s := _saw(dur, f * (1.0 + (_rng.randf() - 0.5) * 0.01), 0.3, 9.0, 0.01)
		_mix(out, s, 0.0, 1.0)
	_lowpass(out, 4000.0)
	var nz := _noise(0.3)
	_highpass(nz, 2000.0)
	_env(nz, 0.001, 0.06)
	_mix(out, nz, 0.0, 1.5)
	_env(out, 0.004, 0.55)
	var hit := _sine_sweep(0.5, 70.0, 30.0, 1.0)
	_env(hit, 0.001, 0.12)
	_mix(out, hit, 0.0, 1.5)
	_distort(out, 1.4)
	_normalize(out, 0.95)
	return out


static func _sting_low() -> PackedFloat32Array:
	var dur := 3.2
	var out := _silence(dur)
	var freqs: Array[float] = [55.0, 58.3, 82.4, 87.3, 116.5]
	for f: float in freqs:
		var s := _saw(dur, f, 0.3, 0.5 + _rng.randf(), 0.01)
		_mix(out, s, 0.0, 1.0)
	_lowpass(out, 700.0)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var e := minf(t / 0.35, 1.0) * exp(-maxf(t - 0.35, 0.0) / 1.1)
		out[i] *= e
	var boom := _sine_sweep(1.0, 50.0, 28.0, 1.0)
	_env(boom, 0.01, 0.35)
	_mix(out, boom, 0.0, 1.2)
	_normalize(out, 0.9)
	return out


static func _scream(dur: float) -> PackedFloat32Array:
	# Hurlement de screamer : aigu, strident, avec formants et un peu de bruit.
	var src := _silence(dur)
	var freqs: Array[float] = [330.0, 415.0, 523.0, 659.0]
	for f: float in freqs:
		var v := _saw(dur, f, 0.3, 11.0 + _rng.randf() * 3.0, 0.07, f * 0.75)
		_mix(src, v, 0.0, 1.0)
	var f1 := src.duplicate()
	_bandpass(f1, 1100.0, 2.0, 800.0)
	var f2 := src.duplicate()
	_bandpass(f2, 2800.0, 3.0, 2000.0)
	var out := _silence(dur)
	_mix(out, f1, 0.0, 1.0)
	_mix(out, f2, 0.0, 0.9)
	var nz := _noise(dur)
	_bandpass(nz, 3000.0, 1.0, 1500.0)
	_mix(out, nz, 0.0, 0.18)
	_normalize(out, 1.0)
	_distort(out, 2.2)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / float(n)
		out[i] *= minf(t / 0.005, 1.0) * (1.0 if t < 0.6 else (1.0 - t) / 0.4)
	_normalize(out, 0.97)
	return out


static func _bang() -> PackedFloat32Array:
	var out := _silence(1.7)
	var th := _sine_sweep(0.9, 58.0, 28.0, 1.0)
	_env(th, 0.001, 0.25)
	_mix(out, th, 0.0, 1.0)
	var nb := _noise(0.3)
	_lowpass(nb, 2000.0)
	_env(nb, 0.0005, 0.06)
	_mix(out, nb, 0.0, 1.3)
	var tail := _brown(1.6)
	_lowpass(tail, 100.0)
	_env(tail, 0.02, 0.5)
	_mix(out, tail, 0.0, 2.0)
	_distort(out, 1.6)
	_normalize(out, 0.95)
	return out


static func _brown(sec: float) -> PackedFloat32Array:
	var b := _noise(sec)
	var y := 0.0
	for i: int in range(b.size()):
		y = (y + b[i] * 0.02) * 0.998
		b[i] = y
	_normalize(b, 1.0)
	return b


static func _knock() -> PackedFloat32Array:
	var out := _silence(1.0)
	var times: Array[float] = [0.0, 0.28, 0.5]
	for t: float in times:
		var th := _sine_sweep(0.12, 150.0, 90.0, 1.0)
		_env(th, 0.001, 0.03)
		_mix(out, th, t, 1.0)
		var nb := _noise(0.08)
		_bandpass(nb, 800.0, 1.5)
		_env(nb, 0.001, 0.02)
		_mix(out, nb, t, 1.0)
	_normalize(out, 0.9)
	return out


static func _glass() -> PackedFloat32Array:
	var out := _silence(1.3)
	var nb := _noise(0.4)
	_highpass(nb, 3000.0)
	_env(nb, 0.0005, 0.08)
	_mix(out, nb, 0.0, 1.0)
	for k: int in range(14):
		var f := 3000.0 + 4000.0 * _rng.randf()
		var s := _sine_sweep(0.3, f, f, 0.5)
		_env(s, 0.0005, 0.03 + 0.1 * _rng.randf())
		_mix(out, s, 0.02 + 0.6 * _rng.randf() * _rng.randf(), 0.6)
	_normalize(out, 0.8)
	return out


static func _thunder() -> PackedFloat32Array:
	_sr = 11025
	var dur := 6.0
	var out := _silence(dur)
	var crack := _noise(0.5)
	_lowpass(crack, 3500.0)
	_env(crack, 0.001, 0.12)
	_mix(out, crack, 0.0, 0.7)
	var rum := _brown(dur)
	_lowpass(rum, 90.0)
	var mod := _noise(dur)
	_lowpass(mod, 2.5)
	_normalize(mod, 1.0)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var e := minf(t / 0.3, 1.0) * exp(-t / 2.2)
		out[i] += rum[i] * e * (0.6 + 0.8 * absf(mod[i]))
	_normalize(out, 0.95)
	return out


# ============================================================ boucles d'ambiance et musique

static func _wind_loop() -> PackedFloat32Array:
	_sr = 11025
	var dur := 9.0
	var nb := _noise(dur)
	var n := nb.size()
	var lo := nb.duplicate()
	_lowpass(lo, 180.0)
	_bandpass(nb, 350.0, 3.0, 520.0)
	var out := _silence(dur)
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var gust := 0.55 + 0.45 * sin(TAU * t / 8.0 * 2.0) * sin(TAU * t * 0.37 + 1.0)
		out[i] = nb[i] * gust * 1.4 + lo[i] * 0.6
	_normalize(out, 0.7)
	return _loopify(out, 1.0)


static func _drone_loop() -> PackedFloat32Array:
	_sr = 11025
	var dur := 9.0
	var out := _silence(dur)
	var n := out.size()
	var freqs: Array[float] = [41.0, 41.375, 61.5, 82.25, 123.0]
	var amps: Array[float] = [0.5, 0.45, 0.25, 0.18, 0.08]
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var s := 0.0
		for k: int in range(freqs.size()):
			s += sin(TAU * freqs[k] * t) * amps[k]
		s += sin(TAU * 987.75 * t) * 0.02 * (0.5 + 0.5 * sin(TAU * t / 4.0))
		out[i] = s
	var nz := _noise(dur)
	_bandpass(nz, 220.0, 1.5)
	_mix(out, nz, 0.0, 0.25)
	_normalize(out, 0.6)
	return _loopify(out, 1.0)


static func _tension_loop() -> PackedFloat32Array:
	_sr = 11025
	var dur := 9.0
	var out := _silence(dur)
	var n := out.size()
	var hf: Array[float] = [311.125, 329.625, 466.125]
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var s := 0.0
		for k: int in range(hf.size()):
			s += sin(TAU * hf[k] * t + sin(TAU * 5.0 * t) * 0.3) * 0.12
		s *= 0.5 + 0.5 * sin(TAU * t / 8.0)
		out[i] = s
	var beat := 0.0
	while beat < dur:
		var p1 := _sine_sweep(0.4, 55.0, 38.0, 1.0)
		_env(p1, 0.005, 0.1)
		_mix(out, p1, beat, 0.55)
		var p2 := _sine_sweep(0.4, 50.0, 36.0, 1.0)
		_env(p2, 0.005, 0.1)
		_mix(out, p2, beat + 0.28, 0.35)
		beat += 1.0
	var nz := _noise(dur)
	_bandpass(nz, 2600.0, 2.0)
	_mix(out, nz, 0.0, 0.05)
	_normalize(out, 0.65)
	return _loopify(out, 1.0)


static func _chase_loop() -> PackedFloat32Array:
	_sr = 16000
	var beat := 0.4
	var bars := 8
	var dur := beat * float(bars) + 0.4
	var out := _silence(dur)
	var bass_notes: Array[float] = [33.0, 33.0, 36.0, 33.0, 34.0, 33.0, 40.0, 39.0, 33.0, 33.0, 36.0, 33.0, 34.0, 33.0, 41.0, 40.0]
	for k: int in range(16):
		var f := _midi(bass_notes[k])
		var s := _saw(0.2, f, 0.5)
		_lowpass(s, 650.0)
		_env(s, 0.003, 0.12)
		_mix(out, s, float(k) * 0.2, 1.0)
	for k: int in range(bars):
		var kick := _sine_sweep(0.25, 90.0, 38.0, 1.0)
		_env(kick, 0.001, 0.07)
		_mix(out, kick, float(k) * beat, 1.1)
		if k % 2 == 1:
			var sn := _noise(0.2)
			_bandpass(sn, 1600.0, 0.9)
			_env(sn, 0.001, 0.05)
			_mix(out, sn, float(k) * beat, 0.7)
		var hat := _noise(0.05)
		_highpass(hat, 5000.0)
		_env(hat, 0.0005, 0.01)
		_mix(out, hat, float(k) * beat + 0.2, 0.3)
	var stab := _silence(0.9)
	var sf: Array[float] = [880.0, 932.3, 1318.5]
	for f: float in sf:
		var s2 := _saw(0.9, f, 0.25, 7.0, 0.01)
		_mix(stab, s2, 0.0, 1.0)
	_lowpass(stab, 3000.0)
	_env(stab, 0.004, 0.25)
	_mix(out, stab, 0.0, 0.5)
	_mix(out, stab, 1.6, 0.35)
	_distort(out, 1.5)
	_normalize(out, 0.8)
	return _loopify(out, 0.4)


static func _clock_tick() -> PackedFloat32Array:
	var out := _silence(2.05)
	var tick := _noise(0.05)
	_bandpass(tick, 3200.0, 3.0)
	_env(tick, 0.0005, 0.008)
	var wood := _sine_sweep(0.05, 1200.0, 1100.0, 0.5)
	_env(wood, 0.0005, 0.01)
	_mix(out, tick, 0.0, 1.0)
	_mix(out, wood, 0.0, 0.8)
	var tock := _noise(0.05)
	_bandpass(tock, 2200.0, 3.0)
	_env(tock, 0.0005, 0.01)
	_mix(out, tock, 1.0, 1.0)
	_mix(out, wood, 1.0, 0.6)
	_normalize(out, 0.5)
	return _loopify(out, 0.05)


static func _clock_chime() -> PackedFloat32Array:
	_sr = 16000
	var out := _silence(4.5)
	var partials: Array[float] = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662]
	var times: Array[float] = [0.0, 1.5]
	for t0: float in times:
		var bell := _silence(3.0)
		var n := bell.size()
		for k: int in range(partials.size()):
			var w := TAU * 220.0 * partials[k] / float(_sr)
			var d := exp(-1.0 / ((1.6 / (1.0 + float(k) * 0.4)) * float(_sr)))
			var g := 1.0 / (1.0 + float(k) * 0.5)
			for i: int in range(n):
				bell[i] += sin(w * float(i)) * g
				g *= d
		_mix(out, bell, t0, 1.0)
	_normalize(out, 0.7)
	return out


static func _drip() -> PackedFloat32Array:
	var out := _silence(0.35)
	var s := _sine_sweep(0.06, 1100.0, 2600.0, 1.0)
	_env(s, 0.001, 0.02)
	_mix(out, s, 0.0, 1.0)
	var sp := _noise(0.1)
	_bandpass(sp, 4000.0, 2.0)
	_env(sp, 0.001, 0.015)
	_mix(out, sp, 0.0, 0.3)
	_normalize(out, 0.5)
	return out


static func _fire_loop() -> PackedFloat32Array:
	_sr = 16000
	var dur := 4.5
	var roar := _brown(dur)
	_lowpass(roar, 400.0)
	var out := _silence(dur)
	_mix(out, roar, 0.0, 0.6)
	var t := 0.0
	while t < dur - 0.05:
		var c := _noise(0.02)
		_highpass(c, 1500.0 + 2500.0 * _rng.randf())
		_env(c, 0.0003, 0.003 + 0.004 * _rng.randf())
		_mix(out, c, t, 0.4 + 0.6 * _rng.randf())
		t += 0.02 + 0.12 * _rng.randf()
	_normalize(out, 0.6)
	return _loopify(out, 0.5)


static func _buzz_loop() -> PackedFloat32Array:
	var dur := 1.2
	var out := _silence(dur)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / float(_sr)
		var s := sin(TAU * 100.0 * t) + 0.5 * sin(TAU * 200.0 * t) + 0.35 * sin(TAU * 300.0 * t) + 0.2 * sin(TAU * 500.0 * t)
		out[i] = clampf(s * 0.8, -0.6, 0.6)
	var nz := _noise(dur)
	_highpass(nz, 3000.0)
	_mix(out, nz, 0.0, 0.1)
	_normalize(out, 0.35)
	return _loopify(out, 0.2)


static func _capture() -> PackedFloat32Array:
	var dur := 2.4
	var out := _silence(dur)
	_mix(out, _scream(1.6), 0.0, 1.0)
	for k: int in range(7):
		var c := _noise(0.02)
		_env(c, 0.0003, 0.004)
		_mix(out, c, 0.35 + float(k) * 0.045 + 0.02 * _rng.randf(), 1.2)
	var hit := _sine_sweep(0.8, 60.0, 25.0, 1.0)
	_env(hit, 0.001, 0.25)
	_mix(out, hit, 0.3, 1.5)
	_distort(out, 1.5)
	_normalize(out, 0.97)
	return out


static func _victory() -> PackedFloat32Array:
	_sr = 16000
	var dur := 7.0
	var out := _silence(dur)
	var n := out.size()
	var chord: Array[float] = [57.0, 64.0, 69.0, 71.0, 76.0]
	for m: float in chord:
		var f := _midi(m)
		for i: int in range(n):
			var t := float(i) / float(_sr)
			var e := minf(t / 2.0, 1.0) * clampf((dur - t) / 2.5, 0.0, 1.0)
			out[i] += sin(TAU * f * t + 0.4 * sin(TAU * 0.3 * t)) * e * 0.2
	_normalize(out, 0.55)
	return out


static func _breath_player() -> PackedFloat32Array:
	var total := 2.8
	var loop_len := 2.6
	var b := _noise(total)
	var n := b.size()
	var inh := b.duplicate()
	_bandpass(inh, 1300.0, 1.8)
	var exh := b.duplicate()
	_bandpass(exh, 750.0, 1.5)
	var out := _silence(total)
	for i: int in range(n):
		var t := fmod(float(i) / float(_sr), loop_len)
		if t < 0.9:
			out[i] = inh[i] * sin(t / 0.9 * PI)
		elif t > 1.05 and t < 2.4:
			out[i] = exh[i] * sin((t - 1.05) / 1.35 * PI) * 1.2
	_normalize(out, 0.5)
	return _loopify(out, 0.2)


static func _hide() -> PackedFloat32Array:
	var out := _silence(0.8)
	_mix(out, _creak(0.5, 45.0, 650.0), 0.0, 0.7)
	var r := _noise(0.4)
	_bandpass(r, 1800.0, 0.9)
	_fade(r, 0.05, 0.2)
	_mix(out, r, 0.2, 0.5)
	_normalize(out, 0.6)
	return out


static func _footsteps_above() -> PackedFloat32Array:
	var out := _silence(2.4)
	var t := 0.0
	for k: int in range(7):
		var th := _sine_sweep(0.3, 70.0, 35.0, 1.0)
		_env(th, 0.002, 0.07)
		_mix(out, th, t, 1.0)
		var nb := _noise(0.2)
		_lowpass(nb, 250.0)
		_env(nb, 0.002, 0.05)
		_mix(out, nb, t, 1.5)
		t += 0.24 + 0.1 * _rng.randf()
	_lowpass(out, 300.0)
	_normalize(out, 0.9)
	return out


static func _whoosh() -> PackedFloat32Array:
	var w := _noise(0.7)
	_bandpass(w, 400.0, 1.2, 2200.0)
	var n := w.size()
	for i: int in range(n):
		w[i] *= sin(float(i) / float(n) * PI)
	_normalize(w, 0.7)
	return w


static func _static() -> PackedFloat32Array:
	var s := _noise(1.0)
	_highpass(s, 1500.0)
	var n := s.size()
	for i: int in range(n):
		if _rng.randf() < 0.002:
			s[i] = 1.0
		s[i] *= 0.4 + 0.6 * _rng.randf()
	_fade(s, 0.02, 0.3)
	_normalize(s, 0.5)
	return s
