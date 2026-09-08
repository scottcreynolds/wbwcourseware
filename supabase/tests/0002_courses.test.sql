begin;
select plan(14);

select has_type('public', 'course_status', 'course status enum exists');
select has_type('public', 'curriculum_item_kind', 'item kind enum exists');
select has_type('public', 'publication_status', 'publication status enum exists');
select has_type('public', 'module_release_mode', 'release mode enum exists');
select has_table('public', 'courses', 'courses table exists');
select has_column('public', 'courses', 'start_date', 'course carries its own dates');
select has_column('public', 'courses', 'timezone', 'course carries its own timezone');
select has_column('public', 'courses', 'intro_markdown', 'course carries a student-facing intro');
select has_table('public', 'course_modules', 'modules table exists');
select has_column('public', 'course_modules', 'release_mode', 'module release scheduling lives on the module directly');
select has_table('public', 'course_items', 'items table exists');
select has_column('public', 'course_items', 'due_at', 'item due date lives on the item directly');
select has_table('public', 'course_module_items', 'placement table exists');
select has_table('public', 'course_item_resources', 'resources table exists');

select * from finish();
rollback;
