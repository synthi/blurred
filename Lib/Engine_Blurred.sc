// archivo: Engine_Blurred.sc
// versión: V309 (Performance: Fast Steal 0.02s)

Engine_Blurred : CroneEngine {
    var <synth, <voices, <vintage_bus, <poly_group;
    var <scale_buf; 
    
    var <bus_vol, <bus_timbre, <bus_mix, <bus_cutoff, <bus_attack, <bus_decay, <bus_sustain;
    var <bus_drift, <bus_noisy_saw, <bus_keytrack, <bus_fb_hpf, <bus_root_freq;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        var server = Crone.server;
        var def_blurred, def_vintage;

        vintage_bus = Bus.audio(server, 2);
        poly_group = ParGroup.new(context.xg);
        voices = Dictionary.new; 
        scale_buf = Buffer.alloc(server, 128, 1);

        // BUSES
        bus_vol = Bus.control(server, 1).set(0.15); 
        bus_timbre = Bus.control(server, 1).set(0);
        bus_mix = Bus.control(server, 1).set(0);
        bus_cutoff = Bus.control(server, 1).set(2000);
        bus_attack = Bus.control(server, 1).set(0.01);
        bus_decay = Bus.control(server, 1).set(0.5);
        bus_sustain = Bus.control(server, 1).set(1.0);
        bus_drift = Bus.control(server, 1).set(0);
        bus_noisy_saw = Bus.control(server, 1).set(0);
        bus_keytrack = Bus.control(server, 1).set(0);
        bus_fb_hpf = Bus.control(server, 1).set(0);
        bus_root_freq = Bus.control(server, 1).set(261.6);

        // VINTAGE POLY
        def_vintage = SynthDef(\vintage_poly, {
            arg outBus, freq=220, gate=1, lpg_mode=1, steal_trig=0; 
            
            var g_vol = In.kr(bus_vol); var g_timbre = In.kr(bus_timbre); var g_mix = In.kr(bus_mix);
            var g_cutoff = In.kr(bus_cutoff); var g_attack = In.kr(bus_attack); var g_decay = In.kr(bus_decay);
            var g_sustain = In.kr(bus_sustain); var g_drift = In.kr(bus_drift); var g_noisy = In.kr(bus_noisy_saw);
            var g_kt = In.kr(bus_keytrack);
            var osc_a, osc_b, sig, env, filter_mod, amp_mod, folded, filter_freq, drift_mod, noise_sig, noise_mix, release_time;

            drift_mod = LFNoise2.kr(0.5).bipolar(g_drift * 0.03); freq = freq * (1 + drift_mod);
            
            // PERFORMANCE FIX: Steal time 20ms (0.02)
            release_time = Select.kr(steal_trig, [g_decay, 0.02]); 
            
            env = EnvGen.ar(Env.adsr(g_attack, g_decay, g_sustain, release_time, 1.0, [-9, 0, -4]), gate, doneAction: 2);
            
            osc_a = SinOsc.ar(freq); folded = osc_a * (1 + (g_timbre * 10)); 
            folded = (folded.abs > 1.0).if((folded.abs % 4).fold2(1.0) * folded.sign, folded);
            folded = folded + (folded.pow(2) * 0.2); folded = LeakDC.ar(folded); osc_a = folded;

            osc_b = OnePole.ar(LFSaw.ar(freq * 1.001), 0.7); noise_sig = WhiteNoise.ar;
            osc_b = osc_b * LinLin.ar(noise_sig, -1, 1, 1 - (g_noisy.min(0.8) * 1.25), 1.0);
            noise_mix = LinLin.kr(g_noisy, 0.8, 1.0, 0, 1).clip(0, 1);
            osc_b = XFade2.ar(osc_b, PinkNoise.ar, (noise_mix * 2) - 1);

            sig = XFade2.ar(osc_a, osc_b, (g_mix * 2) - 1);
            sig = (sig * 1.2) + (sig.pow(2) * 0.1); sig = LeakDC.ar(sig); sig = sig.tanh; 

            filter_mod = Select.kr(lpg_mode, [DC.kr(1), env]); amp_mod = env;
            filter_freq = g_cutoff * (freq / 261.6).pow(g_kt);
            filter_freq = LinExp.kr(filter_mod, 0, 1, 20, filter_freq.clip(20, 20000));
            sig = RLPF.ar(sig, filter_freq, 0.6);
            sig = sig * amp_mod * g_vol * 0.1;
            sig = Pan2.ar(sig, 0);
            Out.ar(outBus, sig);
        });
        def_vintage.add;

        // BLURRED FX
        def_blurred = SynthDef(\blurred, {
            arg inBus, outBus, vintage_in_bus, scale_buf_num,
                amp=1, mix=0.5, frequency=0.5, freq_slew=0.1, time_scale=1.0, decay=0.1, decay_slew=0.1,
                feedback=0, tone=0, polarity=0, skew=0, depth=1.0, wander=0, damping=0, grit=0,
                dyn_res=0, ef_clamp=1, lfo_rate=0.1, lfo_amt=0, div_base=0, lfo_shape=0, fb_tap_pos=7,
                ping_trig=0, ping_pitch=60, ping_amp=1.0, ping_color=0,
                output_mono=0, bass_focus_freq=0, 
                texture_freeze=0, crystal_mode=0,
                ghost_feed=0, time_freeze=0,
                div_swell_gate=0, div_swell_time=0.5,
                tape_stop_gate=0, tape_recover_time=0.5;

            var input, dry, wet, sig, synth_in;
            var numStages = 111;
            var left_chain, right_chain, feedback_sig;
            var lag_freq, lag_decay;
            var lfos, lfo_sig, div_total, div_boost;
            var taps_left = newClear(Array, 8); var taps_right = newClear(Array, 8);
            var tap_indices = [0, 16, 32, 48, 64, 80, 96, 110]; var tap_count = 0;
            var exciter_ping, sig_lp, sig_hp, selector;
            var freq_l, freq_r, time_l, time_r, decay_l, decay_r, pol_l, pol_r, depth_l, depth_r;
            var grit_drive, grit_mix_curve, dec_sr, dec_bits, sig_decimated, tape_wobble;
            var input_env, max_decay, dyn_val, dj_lp_cut, dj_hp_cut;
            var damping_freq, hpf_freq, g_fb_hpf, g_root_freq;
            var wander_freq_mod, active_feedback;
            var real_time_scale, real_input, time_freeze_lag;
            var tape_stop_lag, final_tape_eff;
            var safe_bass_freq, bass_mono_sig; 

            g_fb_hpf = In.kr(bus_fb_hpf);
            g_root_freq = In.kr(bus_root_freq);
            lag_freq = Lag.kr(frequency, freq_slew);
            lag_decay = Lag.kr(decay, decay_slew);

            real_input = Lag.kr(Select.kr(ghost_feed, [1, 0]), 0.1);
            input = In.ar(inBus, 2) * real_input;
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
            div_boost = VarLag.kr(div_swell_gate * 0.5, div_swell_time, 0, \lin);
            div_total = (div_base + (lfo_sig * lfo_amt * 0.45 * (1.0-(wander*0.6))) + div_boost).clip(0, 1);
            
            freq_l = (lag_freq + (div_total.pow(2) * 0.5)).clip(0, 1);
            freq_r = (lag_freq - (div_total.pow(2) * 0.5)).clip(0, 1);
            
            time_freeze_lag = Select.kr(time_freeze, [3.0, 0.1]);
            real_time_scale = VarLag.kr(Select.kr(time_freeze, [time_scale, 0.0001]), time_freeze_lag, 0, \lin);
            
            time_l = (real_time_scale * (1 + (div_total.pow(3) * 0.5))).clip(0.0001, 1.0);
            time_r = (real_time_scale * (1 - (div_total.pow(3) * 0.5))).clip(0.0001, 1.0);
            decay_l = (decay_l * (1 + (div_total * 0.4))).clip(0.001, 10.0);
            decay_r = (decay_r * (1 - (div_total * 0.4))).clip(0.001, 10.0);
            pol_l = (polarity + div_total).clip(-1, 1);
            pol_r = (polarity - div_total).clip(-1, 1);
            depth_l = (depth + (div_total.pow(3) * 0.25)).clip(0, 1);
            depth_r = (depth - (div_total.pow(3) * 0.25)).clip(0, 1);

            feedback_sig = LocalIn.ar(2);
            damping_freq = LinExp.kr(1 - damping, 0, 1, 160, 20000);
            feedback_sig = BLowPass4.ar(feedback_sig, damping_freq, 0.8);
            hpf_freq = Select.kr(g_fb_hpf, [10, 120, 250, 500, 1000]);
            feedback_sig = HPF.ar(feedback_sig, hpf_freq);

            grit_drive = 1 + (grit * 0.4); 
            feedback_sig = (feedback_sig * grit_drive).tanh;
            
            grit_mix_curve = LinLin.kr(grit, 0.5, 1.0, 0.0, 1.0).clip(0, 1);
            dec_sr = LinExp.kr(grit, 0.5, 1.0, 48000, 16000);
            dec_bits = LinLin.kr(grit, 0.5, 1.0, 24, 8);
            sig_decimated = Decimator.ar(feedback_sig, dec_sr, dec_bits);
            feedback_sig = XFade2.ar(feedback_sig, sig_decimated, (grit_mix_curve * 2) - 1);
            
            tape_wobble = LFNoise2.kr(3).bipolar(grit * 0.005); 
            feedback_sig = DelayC.ar(feedback_sig, 0.1, 0.01 + tape_wobble);
            feedback_sig = LeakDC.ar(feedback_sig);
            
            active_feedback = Lag.kr(Select.kr(ghost_feed, [feedback, 0.93]), 0.2);
            sig = dry + (feedback_sig * active_feedback);
            left_chain = sig[0]; right_chain = sig[1];

            wander_freq_mod = Select.kr(texture_freeze, [1.0, 0.0001]); 
            lfos = Array.fill(111, { arg i; 
                LFDNoise1.kr((0.1 + (i * 0.02)) * wander_freq_mod).bipolar(wander * 0.02) 
            });
            
            numStages.do({ arg i;
                var stage_ratio = i / numStages;
                var dist_l = stage_ratio.pow(2.pow(pol_l * 2));
                var dist_r = stage_ratio.pow(2.pow(pol_r * 2));
                var base_l, base_r;
                var normal_l, crystal_l;
                var ratio, spread_oct, target_freq;
                var mod_wander_l, mod_wander_r, headroom_l, headroom_r;
                
                normal_l = (0.0001 * time_l) + (time_l * 0.05 * dist_l * (1.0 - freq_l).pow(2));
                
                ratio = Index.kr(scale_buf_num, i % 16); 
                spread_oct = (i / 16).floor;
                target_freq = g_root_freq * ratio * (2.pow(spread_oct));
                target_freq = target_freq.clip(20, 10000);
                crystal_l = ((1.0 / target_freq) * time_scale).clip(0.0001, 0.05);
                
                base_l = Select.kr(crystal_mode, [normal_l, crystal_l]);
                base_r = base_l; 
                
                headroom_l = (0.049 - base_l).max(0);
                headroom_r = (0.049 - base_r).max(0);
                mod_wander_l = lfos[i] * wander * 0.03 * time_l;
                mod_wander_r = lfos[i] * wander * 0.03 * time_r;
                base_l = base_l + mod_wander_l.clip(headroom_l.neg, headroom_l);
                base_r = base_r + mod_wander_r.clip(headroom_r.neg, headroom_r);
                
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
            
            sig = XFade2.ar(dry, wet, (mix * 2) - 1) * amp;
            safe_bass_freq = bass_focus_freq.max(20);
            bass_mono_sig = (HPF.ar(sig, safe_bass_freq) + LPF.ar((sig[0]+sig[1])*0.7, safe_bass_freq).dup);
            sig = Select.ar(bass_focus_freq > 0, [sig, bass_mono_sig]);
            sig = Select.ar(output_mono, [sig, (sig[0] + sig[1]) ! 2 * 0.707]);
            
            tape_stop_lag = Select.kr(tape_stop_gate, [tape_recover_time, 0.5]);
            final_tape_eff = VarLag.kr(tape_stop_gate, tape_stop_lag, 0, \lin);
            sig = DelayC.ar(sig, 0.2, final_tape_eff * 0.2);
            sig = sig * (1 - final_tape_eff);

            Out.ar(outBus, sig);
        });
        def_blurred.add;
        context.server.sync;

        synth = Synth.new(\blurred, [\inBus, context.in_b, \outBus, context.out_b, \vintage_in_bus, vintage_bus, \scale_buf_num, scale_buf.bufnum], context.xg, \addToTail);

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
        this.addCommand("vintage_sustain", "f", { arg msg; bus_sustain.set(msg[1]); });
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
        this.addCommand("vintage_note_off", "i", { arg msg; var id = msg[1]; if (voices.at(id).notNil) { voices.at(id).set(\gate, 0); voices.removeAt(id); } });
        this.addCommand("vintage_panic", "", { arg msg; poly_group.freeAll; voices.clear; });
        this.addCommand("vintage_steal", "i", { arg msg; var id = msg[1]; if (voices.at(id).notNil) { voices.at(id).set(\steal_trig, 1, \gate, 0); voices.removeAt(id); } });

        this.addCommand("feedback_hpf", "f", { arg msg; bus_fb_hpf.set(msg[1]); });
        this.addCommand("output_mono", "i", { arg msg; synth.set(\output_mono, msg[1]); });
        this.addCommand("texture_freeze", "i", { arg msg; synth.set(\texture_freeze, msg[1]); });
        this.addCommand("crystal_mode", "i", { arg msg; synth.set(\crystal_mode, msg[1]); });
        this.addCommand("ghost_feed", "i", { arg msg; synth.set(\ghost_feed, msg[1]); });
        this.addCommand("time_freeze", "i", { arg msg; synth.set(\time_freeze, msg[1]); });
        this.addCommand("div_swell", "i", { arg msg; synth.set(\div_swell_gate, msg[1]); });
        this.addCommand("div_swell_time", "f", { arg msg; synth.set(\div_swell_time, msg[1]); });
        this.addCommand("tape_stop", "i", { arg msg; synth.set(\tape_stop_gate, msg[1]); });
        this.addCommand("tape_recover", "f", { arg msg; synth.set(\tape_recover_time, msg[1]); });
        this.addCommand("bass_focus", "f", { arg msg; synth.set(\bass_focus_freq, msg[1]); });
        this.addCommand("update_scale_data", "fffffffffffffffff", { arg msg; var root = msg[1]; var data = msg.copyRange(2, msg.size - 1); bus_root_freq.set(root); scale_buf.setn(0, data); });
    }

    free {
        synth.free; vintage_bus.free; poly_group.free; scale_buf.free;
        bus_vol.free; bus_timbre.free; bus_mix.free; bus_cutoff.free; bus_attack.free; bus_decay.free; bus_sustain.free;
        bus_drift.free; bus_noisy_saw.free; bus_keytrack.free; bus_fb_hpf.free; bus_root_freq.free;
        voices.do({ arg v; v.free; });
    }
}
