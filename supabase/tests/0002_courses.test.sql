begin;
select plan(12);

select has_type('public', 'course_status', 'course status enum exists');
select has_type('public', 'curriculum_item_kind', 'item kind enum exists');
select has_type('public', 'publication_status', 'publication status enum exists');
select has_table('public', 'courses', 'courses table exists');
select has_table('public', 'course_modules', 'modules table exists');
select has_table('public', 'course_items', 'items table exists');
select has_table('public', 'course_module_items', 'placement table exists');
select has_table('public', 'course_item_resources', 'resources table exists');
select policies_are(
  'public',
  'courses',
  array['student reads course metadata for enrolled cohort', 'teacher manages own courses'],
  'course access is explicit'
);
select policies_are('public', 'course_modules', array['teacher manages own course modules'], 'module access is explicit');
select policies_are('public', 'course_items', array['teacher manages own course items'], 'item access is explicit');
select policies_are('public', 'course_item_resources', array['teacher manages own item resources'], 'resource access is explicit');

select * from finish();
rollback;
