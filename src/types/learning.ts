import type {CurriculumItemKind} from '@/types/course'
export type LearningItemSummary={id:string;title:string;kind:CurriculumItemKind;dueAt:string|null;position:number}
export type LearningModule={id:string;title:string;description:string;position:number;isVisible:boolean;releaseAt:string|null;items:LearningItemSummary[]}
export type LearningOutline={cohort:{id:string;title:string;courseId:string;startDate:string;endDate:string;timezone:string;introMarkdown:string};course:{title:string;branding:Record<string,unknown>};modules:LearningModule[]}

