begin;
select plan(7);

select has_type('public', 'app_role', 'app_role enum exists');
select enum_has_labels('public', 'app_role', array['teacher', 'student'], 'roles are constrained');
select has_table('public', 'profiles', 'profiles table exists');
select has_column('public', 'profiles', 'role', 'profiles include role');
select policies_are(
  'public',
  'profiles',
  array['teacher reads enrolled student profiles', 'users can read their own profile'],
  'profiles expose only explicit read policies'
);
select table_privs_are(
  'public',
  'profiles',
  'authenticated',
  array['SELECT'],
  'authenticated users cannot write profiles directly'
);
select results_eq(
  $$select count(*)::bigint from pg_indexes where schemaname = 'public' and indexname = 'profiles_single_teacher_unique'$$,
  array[1::bigint],
  'database enforces one teacher profile'
);

select * from finish();
rollback;
