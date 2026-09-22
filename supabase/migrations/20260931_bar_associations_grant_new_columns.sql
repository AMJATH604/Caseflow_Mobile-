-- bar_associations is locked to a column GRANT list so invite_code cannot be
-- read off the table — joining goes through claim_bar_membership(), not
-- through reading the code.
--
-- 20260929 added six columns without extending that list, so office-bearer
-- names, contact details and the stipend floor were unreadable: any select
-- touching them was refused outright. That is also why the admin lookup
-- broke — it selected bar_associations(*), the * included invite_code, the
-- whole query was denied, the error was swallowed, and every page fell back
-- to an empty association id.
--
-- invite_code stays off the list deliberately.

GRANT SELECT (
  president_name,
  secretary_name,
  treasurer_name,
  contact_phone,
  contact_email,
  junior_stipend_floor
) ON public.bar_associations TO authenticated;

-- Office-bearers maintain these from Settings.
GRANT UPDATE (
  president_name,
  secretary_name,
  treasurer_name,
  contact_phone,
  contact_email,
  junior_stipend_floor
) ON public.bar_associations TO authenticated;
