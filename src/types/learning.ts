import type {CurriculumItemKind, PublicationStatus} from '@/types/course'
export type LearningItemSummary={id:string;title:string;kind:CurriculumItemKind;dueAt:string|null;position:number}
export type LearningModule={id:string;title:string;description:string;position:number;isVisible:boolean;releaseAt:string|null;items:LearningItemSummary[]}
export type LearningOutline={course:{id:string;title:string;branding:Record<string,unknown>;startDate:string;endDate:string;timezone:string;introMarkdown:string};modules:LearningModule[]}
export type LearningItemDetail={id:string;courseId:string;kind:CurriculumItemKind;title:string;bodyMarkdown:string;publicationStatus:PublicationStatus;dueAt:string|null}
