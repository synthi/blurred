// archivo: Engine_Blurred.sc
// versión: V126 (Node Order Fix: AddToTail)
// descripción: Soluciona el silencio forzando al FX a procesar DESPUÉS de las voces.

Engine_Blurred : CroneEngine {
    var <synth, <voices, <vintage_bus;
    var <poly_group; 
    
    var <bus_vol, <bus_timbre, <bus_mix, <bus_cutoff, <bus_attack, <bus_decay;
    var <bus_drift, <bus_noisy_saw, <bus_keytrack;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        var server = Crone.server;
        var def_blurred, def_vintage;

        vintage_bus = Bus.audio(server, 2);
        
        // 1. Crear Grupo para voces (Se añade a la CABEZA por defecto)
        poly_group = ParGroup.new(context.xg);

        // BUSES GLOBALES
        bus_vol = Bus.control(server, 1).set(0.5); 
        bus_timbre = Bus.control(server, 1).set(0);
        bus_mix = Bus.control(server, 1).set(0);
        bus_cutoff = Bus.control(server, 1).set(2000);
        bus_attack = Bus.control(server, 1).set(0.01);
        bus_decay = Bus.control(server, 1).set(0.5);
        bus_drift = Bus.control(server, 1).set(0);
        bus_noisy_saw = Bus.control(server, 1).set(0);
        bus_keytrack = Bus.control(server, 1).set(0);

        // --------------------------------------------------------
        // VINTAGE POLY
        // --------------------------------------------------------
        def_vintage = SynthDef(\vintage_poly, {
            arg outBus, freq=220, gate=1, lpg_mode=1; 
            
            var g_vol = In.kr(bus_vol);
            var g_timbre = In.kr(bus_timbre);
            var g_mix = In.kr(bus_mix);
            var g_cutoff = In.kr(bus_cutoff);
            var g_attack = In.kr(bus_attack);
            var g_decay = In.kr(bus_decay);
            var g_drift = In.kr(bus_drift);
            var g_noisy = In.kr(bus_noisy_saw);
            var g_kt = In.kr(bus_keytrack);

            var osc_a, osc_b, sig, env, filter_mod, amp_mod, folded, filter_freq;
            var drift_mod, noise_sig, noise_mix;

            drift_mod = LFNoise2.kr(0.5).bipolar(g_drift * 0.03); 
            freq = freq * (1 + drift_mod);

            // ADSR Plucky (-9 curve)
            env = EnvGen.ar(Env.asr(g_attack, 1, g_decay, [-9, -4]), gate, doneAction: 2);
            
            // OSC A: Sine Wavefolder
            osc_a = SinOsc.ar(freq);
            folded = osc_a * (1 + (g_timbre * 10)); 
            folded = (folded.abs > 1.0).if(
                (folded.abs % 4).fold2(1.0) * folded.sign, folded
            );
            osc_a = folded;

            // OSC B: Noisy Saw XFade
            osc_b = OnePole.ar(LFSaw.ar(freq * 1.001), 0.7);
            noise_sig = WhiteNoise.ar;
            osc_b = osc_b * LinLin.ar(noise_sig, -1, 1, 1 - (g_noisy.min(0.8) * 1.25), 1.0);
            noise_mix = LinLin.kr(g_noisy, 0.8, 1.0, 0, 1).clip(0, 1);
            osc_b = XFade2.ar(osc_b, PinkNoise.ar, (noise_mix * 2) - 1);

            sig = XFade2.ar(osc_a, osc_b, (g_mix * 2) - 1);

            // LPG Logic
            filter_mod = Select.kr(lpg_mode, [DC.kr(1), env]); // 0=VCA, 1=BOTH
            amp_mod = env;

            // Key Tracking + Cutoff
            filter_freq = g_cutoff * (freq / 261.6).pow(g_kt);
            filter_freq = LinExp.kr(filter_mod, 0, 1, 20, filter_freq.clip(20, 20000));
            
            sig = RLPF.ar(sig, filter_freq, 0.6);

            // VOLUMEN MASTER SYNTH (0.1 para seguridad)
            sig = sig * amp_mod * g_vol * 0.1;
            sig = Pan2.ar(sig, 0);
            
            Out.ar(outBus, sig);
        });
        def_vintage.add;

        // --------------------------------------------------------
        // BLURRED FX
        // --------------------------------------------------------
        def_blurred = SynthDef(\blurred, {
            arg inBus, outBus, vintage_in_bus,
                amp=1, mix=0.5, frequency=0.5, freq_slew=0.1, time_scale=1.0, decay=0.1, decay_slew=0.1,
                feedback=0, tone=0, polarity=0, skew=0, depth=1.0, wander=0, damping=0, grit=0,
                dyn_res=0, ef_clamp=1, lfo_rate=0.1, lfo_amt=0, div_base=0, lfo_shape=0, fb_tap_pos=7,
                ping_trig=0, ping_pitch=60, ping_amp=1.0, ping_color=0;

            var input, dry, wet, sig, synth_in;
            var numStages = 111;
            var left_chain, right_chain, feedback_sig;
            var lag_freq, lag_decay;
            var lfos, lfo_sig, div_total;
            var taps_left = newClear(Array, 8);
            var taps_right = newClear(Array, 8);
            var tap_indices = [0, 16, 32, 48, 64, 80, 96, 110];
            var tap_count = 0;
            var exciter_ping, sig_lp, sig_hp, selector;
            var freq_l, freq_r, time_l, time_r, decay_l, decay_r, pol_l, pol_r, depth_l, depth_r;
            var grit_drive, grit_stage_mask, dec_sr, dec_bits, sig_decimated, tape_wobble;
            var input_env, max_decay, dyn_val, dj_lp_cut, dj_hp_cut;

            lag_freq = Lag.kr(frequency, freq_slew);
            lag_decay = Lag.kr(decay, decay_slew);

            input = In.ar(inBus, 2);
            synth_in = In.ar(vintage_in_bus, 2);
            
            exciter_ping = SinOsc.ar(ping_pitch.midicps) + PinkNoise.ar(0.8);
            sig_lp = LPF.ar(exciter_ping, LinExp.kr(ping_color + 1.01, 0.01, 1.01, 150, 9000));
            sig_hp = HPF.ar(exciter_ping, LinExp.kr(ping_color + 0.01, 0.01, 1.01, 150, 8000));
            selector = ping_color + 1; 
            exciter_ping = SelectX.ar(selector, [sig_lp, exciter_ping, sig_hp]);
            exciter_ping = exciter_ping * EnvGen.ar(Env.perc(0.001, 0.1), K2A.ar(ping_trig)) * ping_amp;
            exciter_ping = exciter_ping.tanh;

            dry = input + synth_in + exciter_ping;

            input_env = Amplitude.kr(Mix.ar(dry), 0.01, 0.1); 
            max_decay = Select.kr(ef_clamp, [DC.kr(30.0), lag_decay]);
            dyn_val = input_env.linlin(0, 1, 0, max_decay);
            decay_l = XFade2.kr(lag_decay, dyn_val, (dyn_res * 2) - 1);
            decay_r = XFade2.kr(lag_decay, dyn_val, (dyn_res * 2) - 1);

            lfo_sig = Select.kr(lfo_shape, [SinOsc.kr(lfo_rate), LFTri.kr(lfo_rate), LFSaw.kr(lfo_rate), LFPulse.kr(lfo_rate).bipolar, LFNoise0.kr(lfo_rate), LFNoise1.kr(lfo_rate)]);
            div_total = (div_base + (lfo_sig * lfo_amt)).clip(0, 1);
            
            freq_l = (lag_freq + (div_total.pow(2) * 0.5)).clip(0, 1);
            freq_r = (lag_freq - (div_total.pow(2) * 0.5)).clip(0, 1);
            time_l = (time_scale * (1 + (div_total.pow(3) * 0.5))).clip(0.01, 1.0);
            time_r = (time_scale * (1 - (div_total.pow(3) * 0.5))).clip(0.01, 1.0);
            decay_l = (decay_l * (1 + (div_total * 0.4))).clip(0.001, 10.0);
            decay_r = (decay_r * (1 - (div_total * 0.4))).clip(0.001, 10.0);
            pol_l = (polarity + div_total).clip(-1, 1);
            pol_r = (polarity - div_total).clip(-1, 1);
            depth_l = (depth + (div_total.pow(3) * 0.25)).clip(0, 1);
            depth_r = (depth - (div_total.pow(3) * 0.25)).clip(0, 1);

            feedback_sig = LocalIn.ar(2);
            feedback_sig = LPF.ar(feedback_sig, 20000 - (damping * 18000));
            grit_drive = 1 + (grit * 0.4); 
            feedback_sig = (feedback_sig * grit_drive).tanh;
            
            grit_stage_mask = grit > 0.85; 
            dec_sr = Select.kr(grit_stage_mask, [LinLin.kr(grit, 0.0, 0.85, 48000, 16000), LinExp.kr(grit, 0.85, 1.0, 16000, 1000)]);
            dec_bits = Select.kr(grit_stage_mask, [LinLin.kr(grit, 0.0, 0.85, 24, 8), LinLin.kr(grit, 0.85, 1.0, 8, 4)]);
            sig_decimated = Decimator.ar(feedback_sig, dec_sr, dec_bits);
            feedback_sig = XFade2.ar(feedback_sig, sig_decimated, (grit * 0.5 * 2) - 1);
            
            tape_wobble = LFNoise2.kr(3).bipolar(grit * 0.005); 
            feedback_sig = Select.ar(grit > 0.5, [feedback_sig, DelayC.ar(feedback_sig, 0.1, 0.01 + tape_wobble)]);
            feedback_sig = LeakDC.ar(feedback_sig);
            
            sig = dry + (feedback_sig * feedback);
            left_chain = sig[0]; right_chain = sig[1];

            lfos = Array.fill(111, { arg i; LFNoise1.kr(0.1 + (i * 0.02)).bipolar(wander * 0.005) });
            
            numStages.do({ arg i;
                var stage_ratio = i / numStages;
                var dist_l = stage_ratio.pow(2.pow(pol_l * 2));
                var dist_r = stage_ratio.pow(2.pow(pol_r * 2));
                var base_l = (0.0001 * time_l) + (time_l * 0.05 * dist_l * (1.0 - freq_l).pow(2));
                var base_r = (0.0001 * time_r) + (time_r * 0.05 * dist_r * (1.0 - freq_r).pow(2));
                base_l = base_l.max(0.00001) + lfos[i];
                base_r = base_r.max(0.00001) + lfos[i];
                base_r = base_r + (skew * 0.01 * stage_ratio);
                left_chain = AllpassL.ar(left_chain, 0.05, base_l.clip(0.00001, 0.05), decay_l);
                right_chain = AllpassL.ar(right_chain, 0.05, base_r.clip(0.00001, 0.05), decay_r);
                if (tap_indices.includes(i), { taps_left.put(tap_count, left_chain); taps_right.put(tap_count, right_chain); tap_count = tap_count + 1; });
            });

            LocalOut.ar([SelectX.ar(fb_tap_pos, taps_left), SelectX.ar(fb_tap_pos, taps_right)].tanh);

            wet = [SelectX.ar(depth_l * 7, taps_left), SelectX.ar(depth_r * 7, taps_right)];
            dj_lp_cut = LinExp.kr(tone.clip(-1.0, 0.0) + 1.01, 0.01, 1.01, 100, 20000);
            wet = LPF.ar(wet, dj_lp_cut);
            dj_hp_cut = LinExp.kr(tone.clip(0.0, 1.0) + 0.01, 0.01, 1.01, 20, 10000);
            wet = HPF.ar(wet, dj_hp_cut);
            
            Out.ar(outBus, XFade2.ar(dry, wet, (mix * 2) - 1) * amp);
        });
        def_blurred.add;
        context.server.sync;

        // AQUÍ ESTÁ EL FIX: \addToTail
        synth = Synth.new(\blurred, [\inBus, context.in_b, \outBus, context.out_b, \vintage_in_bus, vintage_bus], context.xg, \addToTail);

        // [SETTERS IGUAL QUE V125...]
        this.addCommand("mix", "f", { arg msg; synth.set(\mix, msg[1]); });
        this.addCommand("frequency", "f", { arg msg; synth.set(\frequency, msg[1]); });
        this.addCommand("time_scale", "f", { arg msg; synth.set(\time_scale, msg[1]); });
        this.addCommand("decay", "f", { arg msg; synth.set(\decay, msg[1]); });
        this.addCommand("feedback", "f", { arg msg; synth.set(\feedback, msg[1]); });
        this.addCommand("polarity", "f", { arg msg; synth.set(\polarity, msg[1]); });
        this.addCommand("skew", "f", { arg msg; synth.set(\skew, msg[1]); });
        this.addCommand("tone", "f", { arg msg; synth.set(\tone, msg[1]); });
        this.addCommand("depth", "f", { arg msg; synth.set(\depth, msg[1]); });
        this.addCommand("wander", "f", { arg msg; synth.set(\wander, msg[1]); });
        this.addCommand("grit", "f", { arg msg; synth.set(\grit, msg[1]); });
        this.addCommand("damping", "f", { arg msg; synth.set(\damping, msg[1]); });
        this.addCommand("dyn_res", "f", { arg msg; synth.set(\dyn_res, msg[1]); });
        this.addCommand("ef_clamp", "f", { arg msg; synth.set(\ef_clamp, msg[1]); });
        this.addCommand("lfo_rate", "f", { arg msg; synth.set(\lfo_rate, msg[1]); });
        this.addCommand("lfo_amt", "f", { arg msg; synth.set(\lfo_amt, msg[1]); });
        this.addCommand("div_base", "f", { arg msg; synth.set(\div_base, msg[1]); });
        this.addCommand("lfo_shape", "f", { arg msg; synth.set(\lfo_shape, msg[1]); });
        this.addCommand("fb_tap_pos", "f", { arg msg; synth.set(\fb_tap_pos, msg[1]); });
        this.addCommand("ping_trig", "f", { arg msg; synth.set(\ping_trig, msg[1]); });
        this.addCommand("ping_pitch", "f", { arg msg; synth.set(\ping_pitch, msg[1]); });
        this.addCommand("ping_amp", "f", { arg msg; synth.set(\ping_amp, msg[1]); });
        this.addCommand("ping_color", "f", { arg msg; synth.set(\ping_color, msg[1]); });
        this.addCommand("amp", "f", { arg msg; synth.set(\amp, msg[1]); });

        this.addCommand("vintage_vol", "f", { arg msg; bus_vol.set(msg[1]); });
        this.addCommand("vintage_timbre", "f", { arg msg; bus_timbre.set(msg[1]); });
        this.addCommand("vintage_mix", "f", { arg msg; bus_mix.set(msg[1]); });
        this.addCommand("vintage_cutoff", "f", { arg msg; bus_cutoff.set(msg[1]); });
        this.addCommand("vintage_attack", "f", { arg msg; bus_attack.set(msg[1]); });
        this.addCommand("vintage_decay", "f", { arg msg; bus_decay.set(msg[1]); });
        this.addCommand("vintage_drift", "f", { arg msg; bus_drift.set(msg[1]); });
        this.addCommand("vintage_noisy_saw", "f", { arg msg; bus_noisy_saw.set(msg[1]); });
        this.addCommand("vintage_keytrack", "f", { arg msg; bus_keytrack.set(msg[1]); });

        this.addCommand("vintage_note_on", "ifi", { arg msg;
            var id = msg[1];
            var freq = msg[2];
            var mode = msg[3];
            var v = Synth.new(\vintage_poly, [\outBus, vintage_bus, \freq, freq, \lpg_mode, mode, \gate, 1], poly_group);
            if (voices == nil) { voices = Dictionary.new; };
            voices.put(id, v);
        });
        
        this.addCommand("vintage_note_off", "i", { arg msg;
            var id = msg[1];
            if (voices.at(id).notNil) { voices.at(id).set(\gate, 0); voices.removeAt(id); }
        });

        this.addCommand("vintage_panic", "", { arg msg;
            poly_group.freeAll; 
            voices.clear;
        });
    }

    free {
        synth.free; vintage_bus.free; poly_group.free;
        bus_vol.free; bus_timbre.free; bus_mix.free; bus_cutoff.free; bus_attack.free; bus_decay.free;
        bus_drift.free; bus_noisy_saw.free; bus_keytrack.free;
        voices.do({ arg v; v.free; });
    }
}
