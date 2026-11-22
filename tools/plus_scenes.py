"""The "See what Plus changes" block of the Plus page: a tab per tool, a Free / Plus switch and an animated flow.
The flows are drawn in plus_flows.py after the app's real interface (kit: plus_ui.py). Each plays Free, then Plus, once,
and stops on the result ("Watch again" replays). Without JavaScript, or with Reduce Motion, the result stands still."""
import plus_flows
import plus_ui

T = {
"vi": dict(
  id="khac-gi", h="Thấy ngay Plus khác gì",
  free="Miễn phí", plus="Plus", note="Mô phỏng theo giao diện Tidymint", get="Xem giá %s Plus", tabs="Công cụ", switch="So Miễn phí với Plus",
  tools=dict(
    mintangle=("Màn hình rộng, chia đôi chưa đủ?", "Kéo vào mép hoặc bấm phím để chia đôi.", "Kéo lên giữa mép trên, thả vào ô 1/3. Bấm phím xếp tiếp, rồi lưu bố cục."),
    mintclip=("Dán vào là lệch font?", "Giữ 100 mục. Bấm là dán, giữ định dạng gốc.", "Giữ 500 mục, ghim thứ hay dùng. Giữ ⌥ rồi bấm để dán không kèm định dạng."),
    mintbar=("Menu bar chật, icon lẫn vào nhau?", "2 nhóm, mỗi nhóm 4 app. Bấm nhóm là mở quạt, bấm nhóm khác là chuyển.", "Gom hết, tô màu nhóm, xem CPU và bộ nhớ. Kéo trong quạt để đổi chỗ."),
    mintdrop=("Sửa file rồi mới gửi được?", "Lắc là có kệ, gom tối đa 5 món.", "Gom không giới hạn, đổi HEIC sang JPG ngay trên kệ, rồi kéo cả nhóm vào thư."),
    mintsort=("Tải về lúc nào cũng bừa?", "Mintsort không có bản miễn phí.", "Lập kế hoạch, xem trước từng file đi đâu, rồi mới áp dụng. Cần thì Hoàn tác.")),
  again="Xem lại"),
"en": dict(
  id="difference", h="See what Plus changes",
  free="Free", plus="Plus", note="Simulated from the Tidymint interface", get="See %s Plus price", tabs="Tools", switch="Compare Free with Plus",
  tools=dict(
    mintangle=("Wide screen, two halves not enough?", "Drag to an edge or press a key for halves.", "Drag to the top, let go on a third. Fill the rest by key, then save the layout."),
    mintclip=("Pasting breaks your formatting?", "Keeps 100 items. Click to paste with the original formatting.", "Keeps 500 items and your pins. Hold ⌥ and click to paste without formatting."),
    mintbar=("Crowded menu bar, icons everywhere?", "2 groups of 4 apps. Click a group to fan it out, click another to switch.", "Group them all, color a group, see CPU and memory. Drag in the fan to reorder."),
    mintdrop=("Fix files before you can send them?", "Shake for a shelf, gather up to 5 items.", "No limit. Turn HEIC into JPG on the shelf, then drag the whole group into an email."),
    mintsort=("Downloads always a mess?", "Mintsort has no free version.", "Plan, preview where each file goes, then apply. Undo if you need to.")),
  again="Watch again"),
}

CSS = """
.demo{max-width:1080px;margin:0 auto}
.demo-tabs{display:flex;flex-wrap:wrap;justify-content:center;gap:8px;margin:0 0 22px}
.demo-tab{display:inline-flex;align-items:center;gap:8px;min-height:40px;padding:8px 16px;border:1px solid var(--line);border-radius:999px;background:transparent;color:var(--sub);font:600 15px/1 inherit;font-family:inherit;cursor:pointer}
.demo-tab[aria-selected=true]{border-color:var(--leaf);background:#2fd39f1f;color:var(--text)}
.demo-tab svg{color:var(--leaf)}
.demo-panel{display:grid;grid-template-columns:minmax(0,29fr) minmax(0,71fr);gap:28px;align-items:center;padding:26px;border:1px solid var(--line);border-radius:20px;background:var(--card)}
.demo-panel[hidden]{display:none}
.demo-t .tool{margin:0 0 6px;color:var(--leaf);font-size:14px;font-weight:700}
.demo-t h3{margin:0 0 18px;font-size:25px;line-height:1.25}
.demo-sw{display:inline-flex;gap:3px;margin:0 0 14px;padding:3px;border:1px solid #ffffff33;border-radius:999px}
.demo-sw button{min-width:96px;min-height:38px;padding:8px 16px;border:0;border-radius:999px;background:transparent;color:var(--sub);font:inherit;font-size:14px;font-weight:700;cursor:pointer;white-space:nowrap}
.demo-sw button[aria-pressed=true]{background:#ffffff26;color:var(--text)}
.demo-sw .to-plus[aria-pressed=true]{background:var(--leaf);color:var(--bg)}
.demo-say{display:grid;margin:0 0 14px}
.demo-say p{grid-area:1/1;margin:0;color:var(--sub);line-height:1.55}
[data-mode=plus] .say-free,[data-mode=free] .say-plus{visibility:hidden}
.demo-t .get{font-size:14px;font-weight:600}
.demo-v{margin:0;min-width:0}
.demo-v figcaption{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-top:7px;color:var(--sub);font-size:12px}
.demo-v .again{flex:none;min-height:30px;padding:4px 12px;border:1px solid #ffffff33;border-radius:999px;background:transparent;color:var(--text);font:inherit;cursor:pointer;visibility:hidden}
.demo-v .again.on{visibility:visible}
@media (max-width:820px){
 .demo-panel{grid-template-columns:minmax(0,1fr);gap:20px;padding:20px}
 .demo-t h3{font-size:22px;margin-bottom:14px}
}
@media (max-width:600px){
 .demo-tabs{gap:6px}
 .demo-tab{padding:7px 11px;font-size:13px;gap:5px}
 .demo-tab svg{width:15px;height:15px}
 .demo-panel{padding:16px 12px}
}
"""

JS = """<script>
(function(){var root=document.getElementById('demo');if(!root)return;
var tabs=[].slice.call(root.querySelectorAll('[role=tab]')),still=matchMedia('(prefers-reduced-motion: reduce)').matches,timers=[],seen=false;
function stop(){timers.forEach(clearTimeout);timers=[]}
function shown(p,m){p.dataset.mode=m;p.querySelectorAll('[data-set]').forEach(function(b){b.setAttribute('aria-pressed',String(b.dataset.set===m))})}
function play(p,m,then){stop();var sc=p.querySelector('.sc'),again=p.querySelector('.again'),at=sc.dataset[m].split(',').map(Number);
sc.classList.add('now');for(var i=1;i<=at.length+12;i++)sc.classList.remove('s'+i);shown(p,m);
if(still){at.forEach(function(_,i){sc.classList.add('s'+(i+1))});return}
again.classList.remove('on');void sc.offsetWidth;sc.classList.remove('now');
at.forEach(function(ms,i){timers.push(setTimeout(function(){sc.classList.add('s'+(i+1))},ms))});
timers.push(setTimeout(function(){if(then)then();else again.classList.add('on')},at[at.length-1]+(then?1600:900)))}
function both(p){if(still){play(p,'plus');return}play(p,'free',function(){play(p,'plus')})}
function panel(t){return document.getElementById(t.getAttribute('aria-controls'))}
function pick(t,run){stop();tabs.forEach(function(x){var on=x===t;x.setAttribute('aria-selected',String(on));x.tabIndex=on?0:-1;panel(x).hidden=!on});
if(run)both(panel(t))}
tabs.forEach(function(t,i){t.addEventListener('click',function(){seen=true;pick(t,true)});
t.addEventListener('keydown',function(e){var d={ArrowRight:1,ArrowLeft:-1}[e.key];if(!d)return;e.preventDefault();var n=tabs[(i+d+tabs.length)%tabs.length];n.focus();seen=true;pick(n,true)})});
root.querySelectorAll('[data-set]').forEach(function(b){b.addEventListener('click',function(){seen=true;play(b.closest('[data-mode]'),b.dataset.set)})});
root.querySelectorAll('.again').forEach(function(b){b.addEventListener('click',function(){var p=b.closest('[data-mode]');play(p,p.dataset.mode)})});
var f=new URLSearchParams(location.search).get('tu'),start=tabs.filter(function(t){return t.dataset.tool===f})[0];if(start)pick(start,false);
if('IntersectionObserver' in window&&!still){var io=new IntersectionObserver(function(es){if(!es[0].isIntersecting)return;io.disconnect();if(seen)return;seen=true;
both(root.querySelector('[role=tabpanel]:not([hidden])'))},{threshold:.5});io.observe(root)}})();
</script>
"""


def section(lang, tools, icon):
    """`tools`: plus_page.TOOLS (key, name, icon); `icon`: site.icon."""
    t = T[lang]; tabs = panels = ""; css = []
    for i, (key, name, ic) in enumerate(tools):
        pain, free, plus = t["tools"][key]
        screen, rules = plus_flows.FLOWS[key](plus_flows.T[lang])
        css += rules
        tabs += ('<button class="demo-tab" type="button" role="tab" id="tab-%s" data-tool="%s" aria-controls="demo-%s" aria-selected="%s" tabindex="%d">%s%s</button>') % (
            key, key, key, "true" if i == 0 else "false", 0 if i == 0 else -1, icon(ic, 17), name)
        panels += f'''<div class="demo-panel" role="tabpanel" id="demo-{key}" aria-labelledby="tab-{key}" data-mode="plus"{"" if i == 0 else " hidden"}>
      <div class="demo-t"><p class="tool">{name}</p><h3>{pain}</h3>
        <div class="demo-sw" role="group" aria-label="{t["switch"]}"><button type="button" data-set="free" aria-pressed="false">{t["free"]}</button><button class="to-plus" type="button" data-set="plus" aria-pressed="true">{t["plus"]}</button></div>
        <div class="demo-say" aria-live="polite"><p class="say-free">{free}</p><p class="say-plus">{plus}</p></div>
        <a class="get" href="#plus-{key}">{t["get"] % name} <span aria-hidden="true">↑</span></a>
      </div>
      <figure class="demo-v"><div class="screen" aria-hidden="true">{screen}</div><figcaption><span>{t["note"]}</span><button class="again" type="button">↻ {t["again"]}</button></figcaption></figure>
    </div>'''
    style = "".join(css)
    return f'''<section id="{t["id"]}">
  <style>{style}</style>{plus_ui.leaf_mark()}
  <div class="sechead" style="margin-bottom:26px"><h2>{t["h"]}</h2></div>
  <div class="demo" id="demo"><div class="demo-tabs" role="tablist" aria-label="{t["tabs"]}">{tabs}</div>
    {panels}</div>
</section>'''


CSS += plus_ui.CSS
