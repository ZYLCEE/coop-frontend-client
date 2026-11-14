-- Keep this patch narrowly scoped to the existing admin return validator.
-- The admin UI already sends `employerCertification`; the database whitelist
-- rejected it as an invalid affected document kind.
BEGIN;

DO $patch$
DECLARE
  function_oid regprocedure :=
    to_regprocedure('public.mutate_application_verification(text,text,integer,text,jsonb,uuid)');
  function_ddl text;
  old_rule text :=
    'k NOT IN (''validId'',''payslip'',''collateral'',''supporting'')';
  new_rule text :=
    'k NOT IN (''validId'',''payslip'',''collateral'',''employerCertification'',''supporting'')';
  occurrences integer;
BEGIN
  IF function_oid IS NULL THEN
    RAISE EXCEPTION 'Expected public.mutate_application_verification(text,text,integer,text,jsonb,uuid) was not found; no changes made.';
  END IF;

  function_ddl := pg_get_functiondef(function_oid);

  -- Be idempotent when the whitelist has already been updated.
  IF position(new_rule IN function_ddl) > 0 THEN
    RETURN;
  END IF;

  occurrences := (length(function_ddl) - length(replace(function_ddl, old_rule, ''))) / length(old_rule);
  IF occurrences <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one existing affected-document whitelist, found %. No changes made.', occurrences;
  END IF;

  function_ddl := replace(function_ddl, old_rule, new_rule);
  EXECUTE function_ddl;
END;
$patch$;

NOTIFY pgrst, 'reload schema';
COMMIT;
