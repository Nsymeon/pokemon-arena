export function moveRules(m, id) {
 const names={slp:'sleep',par:'paralysis',brn:'burn',psn:'poison',tox:'toxic',frz:'freeze'};
 const effect=names[m.status] || m.volatileStatus || (m.boosts ? Object.entries(m.boosts).map(([s,n])=>`${s}${n>0?'+':''}${n}`).join(' ') : '');
 return {weather:m.weather||'',effect, status:m.status||'',volatile_status:m.volatileStatus||'',stat_changes:m.boosts||{},secondaries:m.secondaries||(m.secondary?[m.secondary]:[]),self_effect:m.self||{},accuracy:m.accuracy===true?true:(m.accuracy??100),powder:!!m.flags?.powder,defrost:!!m.flags?.defrost,charge_time:m.flags?.charge?1:0,action_delay:(m.flags?.charge||m.flags?.recharge)?2:1,requires_recharge:!!m.flags?.recharge,rest:id==='rest',tri_status:id==='triattack'};
}
