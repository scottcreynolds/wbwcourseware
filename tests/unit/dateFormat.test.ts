import {describe,expect,it} from 'vitest'
import {formatCourseDate} from '@/features/learning/dateFormat'
describe('formatCourseDate',()=>{it('uses course timezone',()=>{const value=formatCourseDate('2026-09-03T16:00:00Z','America/New_York');expect(value).toContain('12:00')});it('preserves empty dates',()=>expect(formatCourseDate(null,'UTC')).toBeNull())})
