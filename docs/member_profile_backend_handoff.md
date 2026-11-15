# Member profile editing

The mobile Profile screen allows a signed-in member to edit only their own first name, last name, phone number, and address. The app sends updates through `DatabaseService.updateOwnMemberInfo`, which checks the active user and filters the update by both the member row ID and `user_id`.

The backend must preserve the `Users can update own member data` row-level security policy (`auth.uid() = user_id`) and grant UPDATE only on `first_name`, `last_name`, `phone`, and `address`. Migration `20261115150000_restore_member_profile_self_update.sql` restores those column-level grants for the `authenticated` role. Do not grant table-level UPDATE or add email, Member ID, role, membership type, status, password, or other protected columns to the member app's update scope.

The production grant was verified after applying the migration. Cooperative staff retain their existing protected admin update flow for other account changes.
