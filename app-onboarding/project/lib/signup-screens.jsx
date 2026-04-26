// Signup flow screens for Syanat iOS app
// Blue + white with gradients, follows Syanat design system

const SBLUE = '#3C21C8';
const SBLUE_INK = '#2A17A0';
const SBLUE_LIGHT = '#615DFF';
const SBLUE_TOP = '#3832FF';
const SGRAD = `linear-gradient(160deg, ${SBLUE_TOP} 0%, ${SBLUE} 55%, ${SBLUE_LIGHT} 100%)`;
const SGRAD_BTN = `linear-gradient(135deg, ${SBLUE_TOP} 0%, ${SBLUE} 60%, ${SBLUE_LIGHT} 100%)`;
const SGRAD_SOFT = `linear-gradient(180deg, #F3F1FF 0%, #FFFFFF 60%)`;
const SFONT = "-apple-system, 'SF Pro Text', 'Inter', system-ui, sans-serif";
const SFONT_DISPLAY = "-apple-system, 'SF Pro Display', 'Inter', system-ui, sans-serif";

// Decorative soft gradient orbs used on gradient screens
function GradOrbs() {
  return (
    <>
      <div style={{position:'absolute', top:-80, right:-60, width:260, height:260, borderRadius:'50%',
        background:'radial-gradient(circle, rgba(255,255,255,0.22), rgba(255,255,255,0) 70%)',
        filter:'blur(6px)', pointerEvents:'none'}}/>
      <div style={{position:'absolute', top:120, left:-120, width:320, height:320, borderRadius:'50%',
        background:'radial-gradient(circle, rgba(97,93,255,0.55), rgba(97,93,255,0) 70%)',
        filter:'blur(8px)', pointerEvents:'none'}}/>
      <div style={{position:'absolute', bottom:-100, right:-80, width:300, height:300, borderRadius:'50%',
        background:'radial-gradient(circle, rgba(56,50,255,0.45), rgba(56,50,255,0) 70%)',
        filter:'blur(8px)', pointerEvents:'none'}}/>
    </>
  );
}

// Logo mark — rounded-square purple tile with a wrench+house glyph
function SyanatLogoMark({size=72, onDark=false}) {
  return (
    <div style={{
      width:size, height:size, borderRadius:size*0.28,
      background: onDark ? 'rgba(255,255,255,0.14)' : SGRAD_BTN,
      display:'flex', alignItems:'center', justifyContent:'center',
      boxShadow: onDark
        ? 'inset 0 0 0 1px rgba(255,255,255,0.25), 0 10px 30px rgba(0,0,0,0.25)'
        : '0 12px 28px rgba(60,33,200,0.35)',
      backdropFilter: onDark ? 'blur(12px)' : 'none',
    }}>
      <svg width={size*0.58} height={size*0.58} viewBox="0 0 40 40" fill="none">
        <path d="M8 20L20 9l12 11v12a2 2 0 0 1-2 2H10a2 2 0 0 1-2-2V20z"
          stroke="#fff" strokeWidth="2.4" strokeLinejoin="round"/>
        <path d="M26 22.5l-4.5 4.5-3-3 4.5-4.5a3.5 3.5 0 0 1 4.2-4.2l-2.4 2.4 1.4 1.4 2.4-2.4a3.5 3.5 0 0 1-2.6 5.8z"
          fill="#fff"/>
      </svg>
    </div>
  );
}

// Shared iOS-style status bar inside screens (device frame provides its own)
// The IOSDevice frame already shows the real one, so content starts below.

// Primary gradient CTA
function GradBtn({children, onClick, style={}}) {
  return (
    <button onClick={onClick} style={{
      width:'100%', height:54, border:0, borderRadius:16,
      background: SGRAD_BTN, color:'#fff',
      fontFamily:SFONT, fontSize:17, fontWeight:600, letterSpacing:-0.2,
      cursor:'pointer', boxShadow:'0 10px 24px rgba(60,33,200,0.35), inset 0 1px 0 rgba(255,255,255,0.2)',
      ...style,
    }}>{children}</button>
  );
}

// White pill button (on gradient bg)
function WhiteBtn({children, onClick, style={}}) {
  return (
    <button onClick={onClick} style={{
      width:'100%', height:54, border:0, borderRadius:16,
      background:'rgba(255,255,255,0.14)', color:'#fff',
      fontFamily:SFONT, fontSize:17, fontWeight:600, letterSpacing:-0.2,
      cursor:'pointer', backdropFilter:'blur(12px)',
      boxShadow:'inset 0 0 0 1px rgba(255,255,255,0.3)',
      ...style,
    }}>{children}</button>
  );
}

// Text field with floating label (light version)
function TF({label, value, placeholder, leading=null, trailing=null, type='text', caret=false, style={}}) {
  return (
    <div style={{marginBottom:14}}>
      <div style={{fontFamily:SFONT, fontSize:12, fontWeight:600, color:'#6B6880',
        letterSpacing:0.2, textTransform:'uppercase', marginBottom:8}}>{label}</div>
      <div style={{
        display:'flex', alignItems:'center', gap:10,
        background:'#F4F2FA', borderRadius:14, padding:'14px 16px',
        border:'1px solid #E7E3F3',
        ...style,
      }}>
        {leading}
        <div style={{flex:1, display:'flex', alignItems:'center', gap:2,
          fontFamily:SFONT, fontSize:16, color: value?'#0B0A1F':'#9A97AE', letterSpacing:-0.2}}>
          {type==='password' && value ? '••••••••' : (value || placeholder)}
          {caret && <span style={{display:'inline-block', width:2, height:18, background:SBLUE,
            marginLeft:2, animation:'blink 1s infinite'}}/>}
        </div>
        {trailing}
      </div>
    </div>
  );
}

// Step dots at top of flow screens
function StepDots({total=5, current=0, dark=false}) {
  return (
    <div style={{display:'flex', gap:6, alignItems:'center'}}>
      {Array.from({length:total}).map((_,i)=>{
        const active = i===current;
        const done = i<current;
        return (
          <div key={i} style={{
            width: active? 22 : 6, height:6, borderRadius:3,
            background: done
              ? (dark? 'rgba(255,255,255,0.9)' : SBLUE)
              : active
                ? (dark? '#fff' : SBLUE)
                : (dark? 'rgba(255,255,255,0.3)' : '#DCD8EC'),
            transition:'all .2s',
          }}/>
        );
      })}
    </div>
  );
}

// Top nav row with back chevron + step dots
function FlowTop({onBack, step, total=5, dark=false}) {
  const c = dark? '#fff':'#0B0A1F';
  return (
    <div style={{display:'flex', alignItems:'center', justifyContent:'space-between',
      padding:'8px 20px 14px'}}>
      <button onClick={onBack} style={{
        width:40, height:40, borderRadius:20, border:0, cursor:'pointer',
        background: dark? 'rgba(255,255,255,0.14)' : '#F4F2FA',
        backdropFilter: dark? 'blur(12px)':'none',
        display:'flex', alignItems:'center', justifyContent:'center',
        boxShadow: dark? 'inset 0 0 0 1px rgba(255,255,255,0.18)' : 'none',
      }}>
        <svg width="10" height="16" viewBox="0 0 10 16" fill="none">
          <path d="M8 2L2 8l6 6" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </button>
      <StepDots total={total} current={step} dark={dark}/>
      <div style={{width:40}}/>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// SCREEN 1 — WELCOME (gradient hero)
// ──────────────────────────────────────────────────────────
function ScreenWelcome() {
  return (
    <div style={{
      width:'100%', height:'100%', position:'relative', overflow:'hidden',
      background: SGRAD, color:'#fff',
      fontFamily:SFONT, display:'flex', flexDirection:'column',
    }}>
      <GradOrbs/>
      <div style={{height:54}}/>{/* status bar */}
      <div style={{flex:1, padding:'24px 28px 0', display:'flex', flexDirection:'column',
        alignItems:'flex-start', position:'relative', zIndex:1}}>
        <SyanatLogoMark size={68} onDark/>
        <div style={{marginTop:'auto', paddingBottom:20}}>
          <div style={{fontFamily:SFONT_DISPLAY, fontSize:44, fontWeight:800, lineHeight:1.03,
            letterSpacing:-1.2, marginBottom:16}}>
            Home fixes,<br/>a tap away.
          </div>
          <div style={{fontSize:17, lineHeight:1.45, color:'rgba(255,255,255,0.82)',
            letterSpacing:-0.2, maxWidth:320}}>
            Book vetted technicians for AC, plumbing, electrical and more — right from your phone.
          </div>
        </div>
      </div>
      <div style={{padding:'0 24px 12px', position:'relative', zIndex:1,
        display:'flex', flexDirection:'column', gap:10}}>
        <button style={{
          width:'100%', height:54, border:0, borderRadius:16,
          background:'#fff', color:SBLUE,
          fontFamily:SFONT, fontSize:17, fontWeight:700, letterSpacing:-0.2,
          cursor:'pointer',
          boxShadow:'0 10px 30px rgba(0,0,0,0.18)',
        }}>Create account</button>
        <WhiteBtn>I already have an account</WhiteBtn>
        <div style={{textAlign:'center', fontSize:12, color:'rgba(255,255,255,0.7)',
          padding:'12px 10px 4px', lineHeight:1.5}}>
          By continuing you agree to our <u>Terms</u> and <u>Privacy Policy</u>.
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// SCREEN 2 — PHONE (light, centered, large)
// ──────────────────────────────────────────────────────────
function ScreenPhone() {
  return (
    <div style={{width:'100%', height:'100%', background:SGRAD_SOFT,
      fontFamily:SFONT, display:'flex', flexDirection:'column', position:'relative'}}>
      <div style={{height:54}}/>
      <FlowTop step={0}/>

      {/* Centered content */}
      <div style={{flex:1, display:'flex', flexDirection:'column', justifyContent:'center',
        padding:'0 24px', textAlign:'center'}}>

        {/* Phone icon medallion */}
        <div style={{display:'flex', justifyContent:'center', marginBottom:28}}>
          <div style={{position:'relative'}}>
            <div style={{position:'absolute', inset:-18, borderRadius:'50%',
              background:'radial-gradient(circle, rgba(60,33,200,0.18), rgba(60,33,200,0) 70%)'}}/>
            <div style={{
              width:96, height:96, borderRadius:28, background:SGRAD_BTN,
              display:'flex', alignItems:'center', justifyContent:'center', position:'relative',
              boxShadow:'0 16px 36px rgba(60,33,200,0.35), inset 0 1px 0 rgba(255,255,255,0.25)',
            }}>
              <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                <path d="M11 5h7l3 8-4 3c1.5 3.5 4 6 7.5 7.5l3-4 8 3v7c0 2-1 3-3 3C18 32 8 22 8 8c0-2 1-3 3-3z"
                  fill="#fff"/>
              </svg>
            </div>
          </div>
        </div>

        <div style={{fontFamily:SFONT_DISPLAY, fontSize:36, fontWeight:800, color:'#0B0A1F',
          letterSpacing:-1, lineHeight:1.05, marginBottom:14}}>
          What's your<br/>phone number?
        </div>
        <div style={{fontSize:16, color:'#5B5973', lineHeight:1.5, marginBottom:36,
          letterSpacing:-0.1, padding:'0 6px'}}>
          We'll text you a 6-digit code to verify it's really you.
        </div>

        {/* Phone field — bigger, centered */}
        <div style={{display:'flex', gap:10, marginBottom:24}}>
          <div style={{
            display:'flex', alignItems:'center', gap:8,
            background:'#fff', borderRadius:16, padding:'18px 16px',
            border:'1px solid #E7E3F3',
            boxShadow:'0 4px 10px rgba(17,12,46,0.05)',
          }}>
            <span style={{fontSize:24, lineHeight:1}}>🇪🇬</span>
            <span style={{fontFamily:SFONT, fontSize:19, fontWeight:700, color:'#0B0A1F'}}>+20</span>
            <svg width="10" height="6" viewBox="0 0 10 6" fill="none" style={{marginLeft:2}}>
              <path d="M1 1l4 4 4-4" stroke="#5B5973" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <div style={{
            flex:1, display:'flex', alignItems:'center',
            background:'#fff', borderRadius:16, padding:'18px 18px',
            border:`2px solid ${SBLUE}`,
            boxShadow:'0 10px 28px rgba(60,33,200,0.14)',
            fontFamily:SFONT, fontSize:21, fontWeight:700, color:'#0B0A1F', letterSpacing:0.3,
          }}>
            100 234 5678
            <span style={{display:'inline-block', width:2, height:24, background:SBLUE,
              marginLeft:4, animation:'blink 1s infinite'}}/>
          </div>
        </div>
      </div>

      {/* Bottom actions */}
      <div style={{padding:'0 24px 16px'}}>
        <GradBtn style={{height:58, fontSize:18}}>Continue</GradBtn>
        <div style={{display:'flex', alignItems:'center', gap:12, margin:'18px 0 14px'}}>
          <div style={{flex:1, height:1, background:'#E0DDEC'}}/>
          <span style={{fontSize:12, color:'#9A97AE', fontWeight:600, letterSpacing:0.5}}>OR</span>
          <div style={{flex:1, height:1, background:'#E0DDEC'}}/>
        </div>
        <div style={{display:'flex', gap:10}}>
          {[
            {l:'Apple', i:(
              <svg width="18" height="22" viewBox="0 0 18 22" fill="#0B0A1F">
                <path d="M13.6 11.5c0-2.6 2.2-3.9 2.3-3.9-1.2-1.8-3.2-2-3.9-2-1.6-.2-3.2.9-4 .9-.8 0-2.1-.9-3.5-.9C2.2 5.7 0 7.5 0 11.2c0 1.1.2 2.2.6 3.3.5 1.4 2.2 4.9 3.9 4.8 1 0 1.7-.7 3-.7s1.9.7 3 .7c1.8 0 3.3-3.2 3.8-4.6-2.4-1.1-2.7-3.2-2.7-3.2zM11.1 3.8c.8-1 1.4-2.3 1.2-3.6-1.1 0-2.5.7-3.3 1.7-.7.8-1.4 2.2-1.2 3.4 1.2.1 2.5-.6 3.3-1.5z"/>
              </svg>
            )},
            {l:'Google', i:(
              <svg width="20" height="20" viewBox="0 0 20 20">
                <path fill="#4285F4" d="M19.6 10.2c0-.7-.1-1.4-.2-2H10v3.8h5.4c-.2 1.2-.9 2.3-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z"/>
                <path fill="#34A853" d="M10 20c2.7 0 5-.9 6.6-2.5L13.4 15c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H1.1v2.6C2.7 17.7 6.1 20 10 20z"/>
                <path fill="#FBBC05" d="M4.4 11.9c-.2-.6-.3-1.2-.3-1.9s.1-1.3.3-1.9V5.5H1.1C.4 6.9 0 8.4 0 10s.4 3.1 1.1 4.5l3.3-2.6z"/>
                <path fill="#EA4335" d="M10 4c1.5 0 2.8.5 3.8 1.5l2.8-2.8C15 1.2 12.7 0 10 0 6.1 0 2.7 2.3 1.1 5.5l3.3 2.6C5.2 5.8 7.4 4 10 4z"/>
              </svg>
            )},
          ].map(s=>(
            <button key={s.l} style={{
              flex:1, height:54, border:'1px solid #E7E3F3', background:'#fff',
              borderRadius:16, cursor:'pointer', display:'flex', alignItems:'center',
              justifyContent:'center', gap:8, fontFamily:SFONT, fontSize:16, fontWeight:600, color:'#0B0A1F',
              boxShadow:'0 2px 6px rgba(17,12,46,0.04)',
            }}>{s.i}{s.l}</button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// SCREEN 3 — OTP
// ──────────────────────────────────────────────────────────
function ScreenOTP() {
  const code = ['4','7','2','','',''];
  const filledCount = 3;
  return (
    <div style={{width:'100%', height:'100%', background:SGRAD_SOFT,
      fontFamily:SFONT, display:'flex', flexDirection:'column', position:'relative'}}>
      <div style={{height:54}}/>
      <FlowTop step={1}/>

      {/* Centered content */}
      <div style={{flex:1, display:'flex', flexDirection:'column', justifyContent:'center',
        padding:'0 20px', textAlign:'center'}}>

        {/* Shield medallion */}
        <div style={{display:'flex', justifyContent:'center', marginBottom:28}}>
          <div style={{position:'relative'}}>
            <div style={{position:'absolute', inset:-18, borderRadius:'50%',
              background:'radial-gradient(circle, rgba(60,33,200,0.18), rgba(60,33,200,0) 70%)'}}/>
            <div style={{
              width:96, height:96, borderRadius:28, background:SGRAD_BTN,
              display:'flex', alignItems:'center', justifyContent:'center', position:'relative',
              boxShadow:'0 16px 36px rgba(60,33,200,0.35), inset 0 1px 0 rgba(255,255,255,0.25)',
            }}>
              <svg width="42" height="42" viewBox="0 0 42 42" fill="none">
                <path d="M21 4l14 5v10c0 9-6 15-14 18-8-3-14-9-14-18V9l14-5z" fill="#fff"/>
                <path d="M14 21l5 5 10-10" stroke={SBLUE} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
          </div>
        </div>

        <div style={{fontFamily:SFONT_DISPLAY, fontSize:36, fontWeight:800, color:'#0B0A1F',
          letterSpacing:-1, lineHeight:1.05, marginBottom:14}}>
          Enter the code
        </div>
        <div style={{fontSize:16, color:'#5B5973', lineHeight:1.5, marginBottom:36,
          letterSpacing:-0.1, padding:'0 8px'}}>
          We sent a 6-digit code to<br/>
          <b style={{color:'#0B0A1F'}}>+20 100 234 5678</b>
        </div>

        {/* 6 big OTP boxes */}
        <div style={{display:'flex', gap:8, justifyContent:'space-between', marginBottom:28,
          width:'100%', boxSizing:'border-box'}}>
          {code.map((d,i)=>{
            const filled = !!d;
            const active = i===filledCount;
            return (
              <div key={i} style={{
                flex:'1 1 0', minWidth:0, height:72, borderRadius:18,
                background: filled ? '#fff' : '#F4F2FA',
                border: active? `2px solid ${SBLUE}` : '1px solid #E7E3F3',
                display:'flex', alignItems:'center', justifyContent:'center',
                fontFamily:SFONT_DISPLAY, fontSize:32, fontWeight:800, color:'#0B0A1F',
                boxShadow: active
                  ? '0 10px 24px rgba(60,33,200,0.18)'
                  : filled ? '0 4px 10px rgba(17,12,46,0.06)' : 'none',
                position:'relative',
              }}>
                {d}
                {active && <span style={{display:'inline-block', width:2, height:32, background:SBLUE,
                  position:'absolute', animation:'blink 1s infinite'}}/>}
              </div>
            );
          })}
        </div>

        <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:6,
          fontSize:15, color:'#5B5973'}}>
          Didn't get it?
          <button style={{background:'none', border:0, color:SBLUE, fontWeight:700,
            fontSize:15, cursor:'pointer', padding:0}}>Resend in 0:24</button>
        </div>
      </div>

      <div style={{padding:'0 24px 16px'}}>
        <GradBtn style={{height:58, fontSize:18}}>Verify</GradBtn>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// SCREEN 4 — PROFILE (name + email + password)
// ──────────────────────────────────────────────────────────
function ScreenProfile() {
  return (
    <div style={{width:'100%', height:'100%', background:SGRAD_SOFT,
      fontFamily:SFONT, display:'flex', flexDirection:'column', position:'relative'}}>
      <div style={{height:54}}/>
      <FlowTop step={2}/>
      <div style={{padding:'4px 28px 0', flex:1, overflow:'auto'}}>
        <div style={{fontFamily:SFONT_DISPLAY, fontSize:30, fontWeight:800, color:'#0B0A1F',
          letterSpacing:-0.8, lineHeight:1.1, marginBottom:10}}>
          Tell us about<br/>yourself
        </div>
        <div style={{fontSize:15, color:'#5B5973', lineHeight:1.45, marginBottom:24, letterSpacing:-0.1}}>
          So technicians know who they're serving.
        </div>

        {/* avatar picker */}
        <div style={{display:'flex', justifyContent:'center', marginBottom:24}}>
          <div style={{position:'relative'}}>
            <div style={{
              width:92, height:92, borderRadius:'50%',
              background: SGRAD_BTN,
              display:'flex', alignItems:'center', justifyContent:'center',
              color:'#fff', fontFamily:SFONT_DISPLAY, fontSize:34, fontWeight:800,
              letterSpacing:-0.5,
              boxShadow:'0 10px 24px rgba(60,33,200,0.3)',
            }}>LH</div>
            <div style={{position:'absolute', bottom:-2, right:-2, width:32, height:32,
              borderRadius:'50%', background:'#fff', display:'flex', alignItems:'center',
              justifyContent:'center', boxShadow:'0 4px 10px rgba(0,0,0,0.14)',
              border:`2px solid #fff`}}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <path d="M10.5 4L9.3 2.8c-.2-.2-.5-.3-.8-.3H5.5c-.3 0-.6.1-.8.3L3.5 4H2a1 1 0 00-1 1v6a1 1 0 001 1h10a1 1 0 001-1V5a1 1 0 00-1-1h-1.5zM7 10.5A2.5 2.5 0 014.5 8 2.5 2.5 0 017 5.5 2.5 2.5 0 019.5 8 2.5 2.5 0 017 10.5z"
                  fill={SBLUE}/>
              </svg>
            </div>
          </div>
        </div>

        <TF label="Full name" value="Layla Hassan" leading={
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <circle cx="9" cy="6" r="3.2" stroke="#5B5973" strokeWidth="1.6"/>
            <path d="M2.5 16c1-3 3.5-4.8 6.5-4.8s5.5 1.8 6.5 4.8" stroke="#5B5973" strokeWidth="1.6" strokeLinecap="round"/>
          </svg>
        }/>
        <TF label="Email" value="layla@example.com" leading={
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <rect x="2" y="3.5" width="14" height="11" rx="2" stroke="#5B5973" strokeWidth="1.6"/>
            <path d="M3 5l6 4.5L15 5" stroke="#5B5973" strokeWidth="1.6" strokeLinecap="round"/>
          </svg>
        }/>
        <TF label="Password" value="secretpass" type="password" leading={
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <rect x="3" y="8" width="12" height="8" rx="2" stroke="#5B5973" strokeWidth="1.6"/>
            <path d="M6 8V5.5a3 3 0 016 0V8" stroke="#5B5973" strokeWidth="1.6" strokeLinecap="round"/>
          </svg>
        } trailing={
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M1 9s3-5 8-5 8 5 8 5-3 5-8 5-8-5-8-5z" stroke="#5B5973" strokeWidth="1.6"/>
            <circle cx="9" cy="9" r="2.5" stroke="#5B5973" strokeWidth="1.6"/>
          </svg>
        }/>

        {/* password strength */}
        <div style={{display:'flex', gap:6, marginTop:-4, marginBottom:6}}>
          {[1,2,3,4].map(i=>(
            <div key={i} style={{flex:1, height:4, borderRadius:2,
              background: i<=3 ? (i<=2? '#15803D': SBLUE_LIGHT) : '#E7E3F3'}}/>
          ))}
        </div>
        <div style={{fontSize:12, color:'#5B5973'}}>Strong — you're good to go.</div>
      </div>
      <div style={{padding:'14px 24px 16px'}}>
        <GradBtn>Continue</GradBtn>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// SCREEN 5 — LOCATION
// ──────────────────────────────────────────────────────────
function ScreenLocation() {
  return (
    <div style={{width:'100%', height:'100%', background:'#fff',
      fontFamily:SFONT, display:'flex', flexDirection:'column', position:'relative', overflow:'hidden'}}>
      {/* Map placeholder with gradient overlay */}
      <div style={{position:'absolute', inset:0}}>
        {/* faux-map grid */}
        <div style={{position:'absolute', inset:0,
          background:`
            linear-gradient(180deg, #EEF0F7 0%, #E3E7F2 100%)`}}/>
        <svg width="100%" height="100%" style={{position:'absolute', inset:0}} viewBox="0 0 400 800" preserveAspectRatio="xMidYMid slice">
          {/* roads */}
          <path d="M-20 180 Q 120 140 260 220 T 440 260" stroke="#fff" strokeWidth="14" fill="none" strokeLinecap="round"/>
          <path d="M-20 180 Q 120 140 260 220 T 440 260" stroke="#D9DEED" strokeWidth="12" fill="none" strokeLinecap="round"/>
          <path d="M60 -20 Q 80 200 200 340 T 380 800" stroke="#fff" strokeWidth="16" fill="none" strokeLinecap="round"/>
          <path d="M60 -20 Q 80 200 200 340 T 380 800" stroke="#D9DEED" strokeWidth="14" fill="none" strokeLinecap="round"/>
          <path d="M-20 520 Q 200 480 440 560" stroke="#fff" strokeWidth="10" fill="none" strokeLinecap="round"/>
          <path d="M-20 520 Q 200 480 440 560" stroke="#D9DEED" strokeWidth="8" fill="none" strokeLinecap="round"/>
          <path d="M-20 680 L 440 640" stroke="#fff" strokeWidth="8" fill="none"/>
          <path d="M-20 680 L 440 640" stroke="#E1E5F0" strokeWidth="6" fill="none"/>
          {/* blocks */}
          <rect x="20" y="40" width="80" height="60" rx="6" fill="#DDE2EF"/>
          <rect x="160" y="60" width="70" height="50" rx="6" fill="#DDE2EF"/>
          <rect x="290" y="40" width="100" height="80" rx="6" fill="#DDE2EF"/>
          <rect x="30" y="280" width="100" height="120" rx="6" fill="#DDE2EF"/>
          <rect x="260" y="380" width="120" height="90" rx="6" fill="#DDE2EF"/>
          <rect x="20" y="580" width="120" height="70" rx="6" fill="#DDE2EF"/>
          <rect x="240" y="680" width="140" height="100" rx="6" fill="#DDE2EF"/>
          {/* park */}
          <circle cx="130" cy="460" r="44" fill="#C9E4CD"/>
          <circle cx="170" cy="500" r="30" fill="#C9E4CD"/>
        </svg>
        {/* pulse pin */}
        <div style={{position:'absolute', top:'38%', left:'50%', transform:'translate(-50%,-50%)'}}>
          <div style={{width:110, height:110, borderRadius:'50%',
            background:`radial-gradient(circle, rgba(60,33,200,0.18), rgba(60,33,200,0) 70%)`}}/>
          <div style={{position:'absolute', top:'50%', left:'50%', transform:'translate(-50%,-50%)',
            width:46, height:46, borderRadius:'50% 50% 50% 0', background:SGRAD_BTN,
            transform:'translate(-50%,-100%) rotate(-45deg)',
            boxShadow:'0 10px 24px rgba(60,33,200,0.4)',
            display:'flex', alignItems:'center', justifyContent:'center'}}>
            <div style={{width:16, height:16, borderRadius:'50%', background:'#fff',
              transform:'rotate(45deg)'}}/>
          </div>
        </div>
        {/* bottom white mask fading */}
        <div style={{position:'absolute', left:0, right:0, bottom:0, height:360,
          background:'linear-gradient(180deg, rgba(255,255,255,0) 0%, #fff 60%)'}}/>
      </div>

      <div style={{height:54, position:'relative', zIndex:2}}/>
      <div style={{position:'relative', zIndex:2}}>
        <FlowTop step={3}/>
      </div>

      <div style={{flex:1}}/>

      {/* Bottom sheet */}
      <div style={{position:'relative', zIndex:2, background:'#fff',
        borderRadius:'28px 28px 0 0', padding:'24px 24px 16px',
        boxShadow:'0 -10px 40px rgba(0,0,0,0.08)'}}>
        <div style={{width:40, height:5, borderRadius:3, background:'#E0DDEC',
          margin:'0 auto 18px'}}/>
        <div style={{fontFamily:SFONT_DISPLAY, fontSize:26, fontWeight:800, color:'#0B0A1F',
          letterSpacing:-0.6, lineHeight:1.1, marginBottom:8}}>
          Where should we send<br/>the technician?
        </div>
        <div style={{fontSize:15, color:'#5B5973', lineHeight:1.45, marginBottom:18}}>
          Turn on location so we can match you with nearby technicians in minutes.
        </div>

        {/* current location row */}
        <div style={{
          display:'flex', alignItems:'center', gap:12,
          background:'#F4F2FA', borderRadius:14, padding:'12px 14px',
          border:'1px solid #E7E3F3', marginBottom:18,
        }}>
          <div style={{width:36, height:36, borderRadius:10, background:SGRAD_BTN,
            display:'flex', alignItems:'center', justifyContent:'center'}}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M8 1C5 1 3 3 3 6c0 4 5 9 5 9s5-5 5-9c0-3-2-5-5-5z" fill="#fff"/>
              <circle cx="8" cy="6" r="1.8" fill={SBLUE}/>
            </svg>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:15, fontWeight:600, color:'#0B0A1F', letterSpacing:-0.1}}>
              Zamalek, Cairo
            </div>
            <div style={{fontSize:12, color:'#5B5973', marginTop:2}}>
              26 July St · ~15 m accuracy
            </div>
          </div>
          <div style={{width:20, height:20, borderRadius:'50%', background:SBLUE,
            display:'flex', alignItems:'center', justifyContent:'center'}}>
            <svg width="10" height="8" viewBox="0 0 10 8" fill="none">
              <path d="M1 4l3 3 5-6" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
        </div>

        <GradBtn>Use my location</GradBtn>
        <button style={{
          width:'100%', height:48, background:'none', border:0, marginTop:8,
          color:'#5B5973', fontFamily:SFONT, fontSize:15, fontWeight:600, cursor:'pointer',
        }}>Enter address manually</button>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────
// SCREEN 6 — SUCCESS (gradient)
// ──────────────────────────────────────────────────────────
function ScreenSuccess() {
  return (
    <div style={{
      width:'100%', height:'100%', position:'relative', overflow:'hidden',
      background: SGRAD, color:'#fff',
      fontFamily:SFONT, display:'flex', flexDirection:'column',
    }}>
      <GradOrbs/>
      <div style={{height:54}}/>
      <div style={{padding:'8px 20px 14px', position:'relative', zIndex:1}}>
        <StepDots total={5} current={4} dark/>
      </div>

      <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center',
        justifyContent:'center', padding:'0 32px', position:'relative', zIndex:1,
        textAlign:'center'}}>
        {/* checkmark medallion */}
        <div style={{position:'relative', marginBottom:32}}>
          <div style={{position:'absolute', inset:-30, borderRadius:'50%',
            background:'radial-gradient(circle, rgba(255,255,255,0.22), rgba(255,255,255,0) 70%)'}}/>
          <div style={{
            width:116, height:116, borderRadius:'50%',
            background:'rgba(255,255,255,0.14)',
            border:'1px solid rgba(255,255,255,0.3)',
            backdropFilter:'blur(12px)',
            display:'flex', alignItems:'center', justifyContent:'center',
            position:'relative',
            boxShadow:'0 20px 40px rgba(0,0,0,0.2)',
          }}>
            <div style={{
              width:78, height:78, borderRadius:'50%', background:'#fff',
              display:'flex', alignItems:'center', justifyContent:'center',
            }}>
              <svg width="38" height="30" viewBox="0 0 38 30" fill="none">
                <path d="M3 15l11 11L35 4" stroke={SBLUE} strokeWidth="5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
          </div>
        </div>

        <div style={{fontFamily:SFONT_DISPLAY, fontSize:34, fontWeight:800, lineHeight:1.05,
          letterSpacing:-1, marginBottom:12}}>
          You're all set,<br/>Layla.
        </div>
        <div style={{fontSize:16, lineHeight:1.5, color:'rgba(255,255,255,0.85)',
          letterSpacing:-0.1, maxWidth:300}}>
          Your account is ready. Let's get your first service booked.
        </div>

        {/* perks */}
        <div style={{marginTop:32, width:'100%', display:'flex', flexDirection:'column', gap:10}}>
          {[
            {t:'Vetted technicians', s:'Background-checked, rated 4.7+'},
            {t:'Transparent pricing', s:'Inspection from 200 EGP'},
          ].map(p=>(
            <div key={p.t} style={{
              display:'flex', alignItems:'center', gap:12, textAlign:'left',
              padding:'12px 14px', borderRadius:14,
              background:'rgba(255,255,255,0.12)',
              border:'1px solid rgba(255,255,255,0.18)',
              backdropFilter:'blur(12px)',
            }}>
              <div style={{width:32, height:32, borderRadius:10,
                background:'rgba(255,255,255,0.2)',
                display:'flex', alignItems:'center', justifyContent:'center'}}>
                <svg width="14" height="11" viewBox="0 0 14 11" fill="none">
                  <path d="M1 5.5l4 4L13 1.5" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div>
                <div style={{fontSize:15, fontWeight:700, letterSpacing:-0.1}}>{p.t}</div>
                <div style={{fontSize:13, color:'rgba(255,255,255,0.75)', marginTop:1}}>{p.s}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div style={{padding:'0 24px 12px', position:'relative', zIndex:1}}>
        <button style={{
          width:'100%', height:54, border:0, borderRadius:16,
          background:'#fff', color:SBLUE,
          fontFamily:SFONT, fontSize:17, fontWeight:700, letterSpacing:-0.2,
          cursor:'pointer', boxShadow:'0 10px 30px rgba(0,0,0,0.2)',
        }}>Browse services</button>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScreenWelcome, ScreenPhone, ScreenOTP, ScreenProfile, ScreenLocation, ScreenSuccess,
  SyanatLogoMark,
});
