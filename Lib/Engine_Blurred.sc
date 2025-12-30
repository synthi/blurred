// archivo: Engine_Blurred.sc
// versión: V115 (Creamy Feedback & Scaled Grit)
// descripción: Grit Drive reducido drásticamente (max 1.4x). Feedback suave. Decimator exacto.

Engine_Blurred : CroneEngine {
    var <synth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // 1. DECLARACIÓN ESTRICTA DE VARIABLES
        var server = Crone.server;
        var def;

        def = SynthDef(\blurred, {
            // -- ARGUMENTOS --
            arg inBus, outBus,
                amp=1, mix=0.5,
                frequency=0.5, freq_slew=0.1,
                time_scale=1.0,
                decay=0.1, decay_slew=0.1,
                feedback=0,
                tone=0,
                polarity=0,
                skew=0,
                depth=1.0, wander=0, damping=0, grit=0,
                
                dyn_res=0, ef_clamp=1,
                
                // Divergence
                lfo_rate=0.1, lfo_amt=0, div_base=0, lfo_shape=0,
                
                // Feedback Tap Select (0.0 - 7.0)
                fb_tap_pos=7,

                // Exciters
                ping_trig=0, ping_pitch=60, ping_amp=1.0, ping_color=0,
                scrape_vel=0, scrape_slew=0.2, scrape_pitch=0.5, scrape_color=0;

            // -- VARIABLES INTERNAS --
            var input, dry, wet, sig;
            var numStages = 111; 
            var exciter_ping, exciter_scrape, combined_exciter;
            var left_chain, right_chain;
            var lag_freq, lag_decay, lag_scrape;
            
            var taps_left = newClear(Array, 8);
            var taps_right = newClear(Array, 8);
            var tap_indices = [0, 16, 32, 48, 64, 80, 96, 110]; 
            var tap_count = 0;

            var lfos; 
            var sig_lp, sig_hp, selector;
            var feedback_sig, fb_source_l, fb_source_r;
            var input_env, max_decay, dyn_val;
            var dj_lp_cut, dj_hp_cut;
            
            // Variables Divergencia
            var lfo_sig, div_total;
            var freq_l, freq_r, time_l, time_r, decay_l, decay_r, pol_l, pol_r, depth_l, depth_r;

            // Variables Grit Macro
            var grit_drive, grit_stage_mask;
            var dec_sr, dec_bits, sig_decimated;
            var tape_wobble;

            // -- CÓDIGO --
            lag_freq = Lag.kr(frequency, freq_slew);
            lag_decay = Lag.kr(decay, decay_slew);
            lag_scrape = Lag.kr(scrape_vel, scrape_slew);

            // 1. LFO ENGINE
            lfo_sig = Select.kr(lfo_shape, [
                SinOsc.kr(lfo_rate),
                LFTri.kr(lfo_rate),
                LFSaw.kr(lfo_rate),
                LFPulse.kr(lfo_rate).bipolar,
                LFNoise0.kr(lfo_rate),
                LFNoise1.kr(lfo_rate)
            ]);
            
            div_total = (div_base + (lfo_sig * lfo_amt)).clip(0, 1);
            
            // 2. DIVERGENCE SPLIT
            freq_l = (lag_freq + (div_total.pow(2) * 0.5)).clip(0, 1);
            freq_r = (lag_freq - (div_total.pow(2) * 0.5)).clip(0, 1);
            
            time_l = (time_scale * (1 + (div_total.pow(3) * 0.5))).clip(0.01, 1.0);
            time_r = (time_scale * (1 - (div_total.pow(3) * 0.5))).clip(0.01, 1.0);
            
            decay_l = (lag_decay * (1 + (div_total * 0.4))).clip(0.001, 10.0);
            decay_r = (lag_decay * (1 - (div_total * 0.4))).clip(0.001, 10.0);
            
            pol_l = (polarity + div_total).clip(-1, 1);
            pol_r = (polarity - div_total).clip(-1, 1);
            
            depth_l = (depth + (div_total.pow(3) * 0.25)).clip(0, 1);
            depth_r = (depth - (div_total.pow(3) * 0.25)).clip(0, 1);

            // 3. INPUT & EXCITERS
            input = In.ar(inBus, 2);
            
            // Ping
            exciter_ping = SinOsc.ar(ping_pitch.midicps);
            exciter_ping = exciter_ping + PinkNoise.ar(0.8);
            sig_lp = LPF.ar(exciter_ping, LinExp.kr(ping_color + 1.01, 0.01, 1.01, 150, 9000));
            sig_hp = HPF.ar(exciter_ping, LinExp.kr(ping_color + 0.01, 0.01, 1.01, 150, 8000));
            selector = ping_color + 1; 
            exciter_ping = SelectX.ar(selector, [sig_lp, exciter_ping, sig_hp]);
            exciter_ping = exciter_ping * EnvGen.ar(Env.perc(0.001, 0.1), K2A.ar(ping_trig));
            exciter_ping = exciter_ping * ping_amp;
            exciter_ping = exciter_ping.tanh; 
            
            // Scrape
            exciter_scrape = PinkNoise.ar(2.0);
            exciter_scrape = BPF.ar(exciter_scrape, 200 + (scrape_pitch * 6000), 0.1);
            sig_lp = LPF.ar(exciter_scrape, LinExp.kr(scrape_color + 1.01, 0.01, 1.01, 150, 9000));
            sig_hp = HPF.ar(exciter_scrape, LinExp.kr(scrape_color + 0.01, 0.01, 1.01, 150, 8000));
            selector = scrape_color + 1;
            exciter_scrape = SelectX.ar(selector, [sig_lp, exciter_scrape, sig_hp]);
            exciter_scrape = exciter_scrape * lag_scrape; 
            exciter_scrape = exciter_scrape * 2.0;
            exciter_scrape = exciter_scrape.tanh; 
            
            combined_exciter = input + exciter_ping + exciter_scrape;
            dry = combined_exciter;

            // 4. DYNAMICS
            input_env = Amplitude.kr(Mix.ar(dry), 0.01, 0.1); 
            max_decay = Select.kr(ef_clamp, [DC.kr(30.0), lag_decay]);
            dyn_val = input_env.linlin(0, 1, 0, max_decay);
            decay_l = XFade2.kr(decay_l, dyn_val, (dyn_res * 2) - 1);
            decay_r = XFade2.kr(decay_r, dyn_val, (dyn_res * 2) - 1);

            // 5. FEEDBACK LOOP
            feedback_sig = LocalIn.ar(2);
            feedback_sig = LPF.ar(feedback_sig, 20000 - (damping * 18000));
            
            // A. Grit: Saturation (ESCALADO 10x MENOS)
            // Antes: 1 + (grit * 4) -> Max 5.0 (Brutal)
            // Ahora: 1 + (grit * 0.4) -> Max 1.4 (Cremoso)
            grit_drive = 1 + (grit * 0.4); 
            feedback_sig = (feedback_sig * grit_drive).tanh;
            
            // B. Grit: Decimator (Curva exacta pedida)
            grit_stage_mask = grit > 0.85; 
            
            // Freq: 48k->16k (0-85%), 16k->1k (85-100%)
            dec_sr = Select.kr(grit_stage_mask, [
                LinLin.kr(grit, 0.0, 0.85, 48000, 16000),
                LinExp.kr(grit, 0.85, 1.0, 16000, 1000)
            ]);
            
            // Bits: 24->8 (0-85%), 8->4 (85-100%)
            dec_bits = Select.kr(grit_stage_mask, [
                LinLin.kr(grit, 0.0, 0.85, 24, 8),
                LinLin.kr(grit, 0.85, 1.0, 8, 4)
            ]);
            
            sig_decimated = Decimator.ar(feedback_sig, dec_sr, dec_bits);
            
            // Mezcla progresiva hasta 50% Wet
            feedback_sig = XFade2.ar(feedback_sig, sig_decimated, (grit * 0.5 * 2) - 1);

            // C. Grit: Tape Wobble (10ms base para evitar artefactos largos)
            tape_wobble = LFNoise2.kr(3).bipolar(grit * 0.005); 
            feedback_sig = Select.ar(grit > 0.5, [feedback_sig, DelayC.ar(feedback_sig, 0.1, 0.01 + tape_wobble)]);

            feedback_sig = LeakDC.ar(feedback_sig); 
            sig = dry + (feedback_sig * feedback);
            
            left_chain = sig[0];
            right_chain = sig[1];

            // ORIGINAL LFO DEFINITION 
            lfos = Array.fill(111, { arg i; 
                LFNoise1.kr(0.1 + (i * 0.02)).bipolar(wander * 0.005) 
            });
            
            taps_left = newClear(Array, 8);
            taps_right = newClear(Array, 8);
            tap_indices = [0, 16, 32, 48, 64, 80, 96, 110]; 
            tap_count = 0;

            // 6. SMEAR CHAIN (RESTAURACIÓN V100)
            numStages.do({ arg i;
                var stage_ratio;
                var dist_l, dist_r;
                var base_l, base_r;
                
                stage_ratio = i / numStages; 
                
                dist_l = stage_ratio.pow(2.pow(pol_l * 2));
                dist_r = stage_ratio.pow(2.pow(pol_r * 2));
                
                base_l = (0.0001 * time_l) + (time_l * 0.05 * dist_l * (1.0 - freq_l).pow(2));
                base_r = (0.0001 * time_r) + (time_r * 0.05 * dist_r * (1.0 - freq_r).pow(2));
                
                // Sin safety clamps
                base_l = base_l.max(0.00001) + lfos[i];
                base_r = base_r.max(0.00001) + lfos[i];

                base_r = base_r + (skew * 0.01 * stage_ratio);

                // El clip V100
                left_chain = AllpassL.ar(left_chain, 0.05, base_l.clip(0.00001, 0.05), decay_l);
                right_chain = AllpassL.ar(right_chain, 0.05, base_r.clip(0.00001, 0.05), decay_r);
                
                if (tap_indices.includes(i), {
                    taps_left.put(tap_count, left_chain);
                    taps_right.put(tap_count, right_chain);
                    tap_count = tap_count + 1;
                });
            });

            fb_source_l = SelectX.ar(fb_tap_pos, taps_left);
            fb_source_r = SelectX.ar(fb_tap_pos, taps_right);

            LocalOut.ar([fb_source_l, fb_source_r].tanh);

            // 7. OUTPUT
            wet = [
                SelectX.ar(depth_l * (tap_count - 1), taps_left),
                SelectX.ar(depth_r * (tap_count - 1), taps_right)
            ];
            
            dj_lp_cut = LinExp.kr(tone.clip(-1.0, 0.0) + 1.01, 0.01, 1.01, 100, 20000);
            wet = LPF.ar(wet, dj_lp_cut);
            dj_hp_cut = LinExp.kr(tone.clip(0.0, 1.0) + 0.01, 0.01, 1.01, 20, 10000);
            wet = HPF.ar(wet, dj_hp_cut);
            
            Out.ar(outBus, XFade2.ar(dry, wet, (mix * 2) - 1) * amp);
        });

        def.add;
        context.server.sync;

        synth = Synth.new(\blurred, [
            \inBus, context.in_b,
            \outBus, context.out_b
        ], context.xg);

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
        
        this.addCommand("scrape_vel", "f", { arg msg; synth.set(\scrape_vel, msg[1]); });
        this.addCommand("scrape_pitch", "f", { arg msg; synth.set(\scrape_pitch, msg[1]); });
        this.addCommand("scrape_color", "f", { arg msg; synth.set(\scrape_color, msg[1]); });
        this.addCommand("ping_trig", "f", { arg msg; synth.set(\ping_trig, msg[1]); });
        this.addCommand("ping_pitch", "f", { arg msg; synth.set(\ping_pitch, msg[1]); });
        this.addCommand("ping_amp", "f", { arg msg; synth.set(\ping_amp, msg[1]); });
        this.addCommand("ping_color", "f", { arg msg; synth.set(\ping_color, msg[1]); });
        this.addCommand("amp", "f", { arg msg; synth.set(\amp, msg[1]); });
    }

    free {
        synth.free;
    }
}
