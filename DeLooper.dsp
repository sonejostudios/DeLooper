declare name        "DeLooper";
declare version     "1.0";
declare author      "Vincent Rateau";
declare license     "GPL v3";
declare reference   "www.sonejo.net";
declare description	"Sample-accurate Looper/Delay with free mode and midi-clock sync mode";

//names: Loolay, Looplay, Deloop, Flooper, Loopa, Echoloop...

import("stdfaust.lib");

// variables at compilation time
loopsec = 32 ; //max loop time (sec)


process =  masterloop ;

masterloop = _ <: _*(1-switcher), _*switcher  :  ((loop*loopvol*mute), _) :> _  ;

			switcher = (rec*looptime) == 0 : si.smooth(0.99) ; // bypass signal if looptime == 0
			loop = + ~ de.fdelay(8388608, looptime)*erase*loopfback ; // fdelay better because sdelay makes a dobble signal bug in free mode


//Compute the loop time in free mode and sync mode and switch between them
////////////////////////////////////
looptime =  select2(sync, counttime, barssync) : _/divide  : looplength : int
with {
			counttime = ba.countup(ma.SR*loopsec, (1-setloop) ) : ba.sAndH(setloop != new)  ; // : looplength2 ;

			// sync mode with more-or-less function
			barssync = counttime  <: barsync2, _ : moreless : _ - midiclock2beat  : _ + setloop*midiclock2beat ;
				barsync2 = _ / midiclock2beat : int : _*midiclock2beat  : _ + midiclock2beat ;
				moreless(x,y) = select2(setrange(x,y), x, x + midiclock2beat ) ;
					setrange(x,y) = (y > (x - midiclock2beat/2))*(y < (x + midiclock2beat/2)) ;
			};


// GUI
/////////////////////
setloop = checkbox("set loop length[midi:ctrl 59]") ;

rec = checkbox("rec[midi:ctrl 60]") ;
new = button("set new loop[midi:ctrl 58]") : ba.impulsify ;
looplength = vbargraph("loop length",0, 44100*loopsec) ; // (== looplength2 in free mode, but snyced in sync mode)
//looplength2 = vbargraph("real loop length",0, 44100*loopsec) ; // the real number of the sample counter
sync = checkbox("sync") ;

erase = 1-button("erase") : si.smooth(0.99);
loopfback = hslider("feedback",1,0,1,0.01) : si.smooth(0.999);
loopvol = hslider("loop vol[midi:ctrl 118]",1,0,1,0.01) : si.smooth(0.999);
mute = 1-checkbox("mute") : si.smooth(0.999);

divide = nentry("divide loop length by",1,1,100,1) : si.smooth(ba.tau2pole(2));


//MIDICLOCK to BEAT (AMOUNT OF SAMPLES IN 1 BEAT) to BPM and SAMPLES
//////////////////////////////////

//send midi clock signal, count sample amount, latch stable signal between beat recognition (after 16000 samples), convert to bpm,
// convert bpm to sample-accurate loop length (in sample)
midiclock2beat = vgroup("MIDI Clock",((clocker, play)) : attach : midi2count <: (_@16000==_@16001), _ : ba.latch : s2bpm : int : bpm2s  : result3)
with{

	//clockersim = ba.pulse(1837.5 /2) ; // replace it with clocker for internal clock for testing

	clocker   = checkbox("Clock Signal[midi:clock]") ; // create a square signal (1/0), changing state at each received clock
	play      = checkbox("Start/Stop Signal[midi:start] [midi:stop]") ; // just to show start stop signal

	// takes clocker signal(24 changes/beat), count samples between every changes, latch the highest number.
	// re-latch to fix the highest number, * by 24 to get on beat (in samples)
	midi2count = _ <: _ != _@1 : ba.countup(8388608,_) : result1 <: _==0,_@1  :  ba.latch  <: _>_@1, _ : ba.latch  : _*24 : result2;


	result1 = _   ; //: vbargraph("samplecount midi", 0, 8388608);
  result2 = _   ; //: vbargraph("sample amount midi2", 0, 8388608);
	result3 = _   ; //: vbargraph("one-beat length (samples) from bpm", 0, 8388608);

	// convert bpm to sample amount for loop length
	bpm2s = 60/_ : _* ma.SR ;

	// round down sampleholder and convert it to bpm
	s2bpm = _/10 : int : _*10 : ma.SR/_ : _*60  : int : bpm ;
	bpm = vbargraph("bpm", 0, 240.0) ;
};
