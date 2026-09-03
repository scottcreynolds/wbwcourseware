begin;
select plan(3);
select has_function('public','get_student_cohort_outline',array['uuid'],'safe student outline exists');
select policies_are('public','courses',array['student reads course metadata for enrolled cohort','teacher manages own courses'],'course metadata access is explicit');
select function_privs_are('public','get_student_cohort_outline',array['uuid'],'authenticated',array['EXECUTE'],'students may request authorized outline');
select * from finish();rollback;
