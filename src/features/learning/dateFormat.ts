export function formatCourseDate(value:string|null,timezone:string):string|null{if(!value)return null;return new Intl.DateTimeFormat(undefined,{dateStyle:'medium',timeStyle:'short',timeZone:timezone}).format(new Date(value))}

