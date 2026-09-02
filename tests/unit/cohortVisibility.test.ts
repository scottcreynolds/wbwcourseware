import {describe,expect,it} from 'vitest'
function visible(mode:'manual'|'scheduled',manual:string|null,scheduled:string|null,now:string){return mode==='manual'?manual!==null:scheduled!==null&&Date.parse(scheduled)<=Date.parse(now)}
describe('cohort module visibility',()=>{it('supports manual and scheduled release',()=>{expect(visible('manual',null,null,'2026-01-01')).toBe(false);expect(visible('manual','2026-01-01',null,'2026-01-01')).toBe(true);expect(visible('scheduled',null,'2026-01-02','2026-01-01')).toBe(false);expect(visible('scheduled',null,'2026-01-01','2026-01-02')).toBe(true)})})
