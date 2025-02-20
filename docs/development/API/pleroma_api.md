# Pleroma API

Requests that require it can be authenticated with [an OAuth token](https://tools.ietf.org/html/rfc6749), the `_pleroma_key` cookie, or [HTTP Basic Authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization).

Request parameters can be passed via [query strings](https://en.wikipedia.org/wiki/Query_string) or as [form data](https://www.w3.org/TR/html401/interact/forms.html). Files must be uploaded as `multipart/form-data`.

The `/api/v1/pleroma/*` path is backwards compatible with `/api/pleroma/*` (`/api/pleroma/*` will be deprecated in the future).

## `/api/v1/pleroma/emoji`
### Lists the custom emoji on that server.
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response:
```json
{
  "girlpower": {
    "tags": [
      "Finmoji"
    ],
    "image_url": "/finmoji/128px/girlpower-128.png"
  },
  "education": {
    "tags": [
      "Finmoji"
    ],
    "image_url": "/finmoji/128px/education-128.png"
  },
  "finnishlove": {
    "tags": [
      "Finmoji"
    ],
    "image_url": "/finmoji/128px/finnishlove-128.png"
  }
}
```
* Note: Same data as Mastodon API’s `/api/v1/custom_emojis` but in a different format

## `/api/pleroma/follow_import`
### Imports your follows, for example from a Mastodon CSV file.
* Method: `POST`
* Authentication: required
* Params:
    * `list`: STRING or FILE containing a whitespace-separated list of accounts to follow
* Response: HTTP 200 on success, 500 on error
* Note: Users that can't be followed are silently skipped.

## `/api/pleroma/blocks_import`
### Imports your blocks.
* Method: `POST`
* Authentication: required
* Params:
    * `list`: STRING or FILE containing a whitespace-separated list of accounts to block
* Response: HTTP 200 on success, 500 on error

## `/api/pleroma/mutes_import`
### Imports your mutes.
* Method: `POST`
* Authentication: required
* Params:
    * `list`: STRING or FILE containing a whitespace-separated list of accounts to mute
* Response: HTTP 200 on success, 500 on error

## `/api/v1/pleroma/captcha`
### Get a new captcha
* Method: `GET`
* Authentication: not required
* Params: none
* Response: Provider specific JSON, the only guaranteed parameter is `type`
* Example response: `{"type": "kocaptcha", "token": "whatever", "url": "https://captcha.kotobank.ch/endpoint", "seconds_valid": 300}`

## `/api/pleroma/delete_account`
### Delete an account
* Method `POST`
* Authentication: required
* Params:
    * `password`: user's password
* Response: JSON. Returns `{"status": "success"}` if the deletion was successful, `{"error": "[error message]"}` otherwise
* Example response: `{"error": "Invalid password."}`

## `/api/pleroma/disable_account`
### Disable an account
* Method `POST`
* Authentication: required
* Params:
    * `password`: user's password
* Response: JSON. Returns `{"status": "success"}` if the account was successfully disabled, `{"error": "[error message]"}` otherwise
* Example response: `{"error": "Invalid password."}`

## `/api/pleroma/accounts/mfa`
#### Gets current MFA settings
* method: `GET`
* Authentication: required
* OAuth scope: `read:security`
* Response: JSON. Returns `{"settings": {"enabled": "false", "totp": false }}`
* Note: `enabled` is whether multi-factor auth is enabled for the user in general, while `totp` is one type of MFA.

## `/api/pleroma/accounts/mfa/setup/totp`
#### Pre-setup the MFA/TOTP method
* method: `GET`
* Authentication: required
* OAuth scope: `write:security`
* Response: JSON. Returns `{"key": [secret_key], "provisioning_uri": "[qr code uri]"  }` when successful, otherwise returns HTTP 422 `{"error": "error_msg"}`

## `/api/pleroma/accounts/mfa/confirm/totp`
#### Confirms & enables MFA/TOTP support for user account.
* method: `POST`
* Authentication: required
* OAuth scope: `write:security`
* Params:
    * `password`: user's password
    * `code`: token from TOTP App
* Response: JSON. Returns `{}` if the enable was successful, HTTP 422 `{"error": "[error message]"}` otherwise


## `/api/pleroma/accounts/mfa/totp`
####  Disables MFA/TOTP method for user account.
* method: `DELETE`
* Authentication: required
* OAuth scope: `write:security`
* Params:
    * `password`: user's password
* Response: JSON. Returns `{}` if the disable was successful, HTTP 422 `{"error": "[error message]"}` otherwise
* Example response: `{"error": "Invalid password."}`

## `/api/pleroma/accounts/mfa/backup_codes`
####  Generstes backup codes MFA for user account.
* method: `GET`
* Authentication: required
* OAuth scope: `write:security`
* Response: JSON. Returns `{"codes": codes}` when successful, otherwise HTTP 422 `{"error": "[error message]"}`

## `/api/v1/pleroma/admin/`
See [Admin-API](admin_api.md)

## `/api/v1/pleroma/notifications/read`
### Mark notifications as read
* Method `POST`
* Authentication: required
* Params (mutually exclusive):
    * `id`: a single notification id to read
    * `max_id`: read all notifications up to this id
* Response: Notification entity/Array of Notification entities that were read. In case of `max_id`, only the first 80 read notifications will be returned.

## `/api/v1/pleroma/accounts/:id/subscribe`
### Subscribe to receive notifications for all statuses posted by a user

Deprecated. `notify` parameter in `POST /api/v1/accounts/:id/follow` should be used instead.

* Method `POST`
* Authentication: required
* Params:
    * `id`: account id to subscribe to
* Response: JSON, returns a mastodon relationship object on success, otherwise returns `{"error": "error_msg"}`
* Example response:
```json
{
  "id": "abcdefg",
  "following": true,
  "followed_by": false,
  "blocking": false,
  "muting": false,
  "muting_notifications": false,
  "subscribing": true,
  "notifying": true,
  "requested": false,
  "domain_blocking": false,
  "showing_reblogs": true,
  "endorsed": false,
  "note": ""
}
```

## `/api/v1/pleroma/accounts/:id/unsubscribe`
### Unsubscribe to stop receiving notifications from user statuses

Deprecated. `notify` parameter in `POST /api/v1/accounts/:id/follow` should be used instead.

* Method `POST`
* Authentication: required
* Params:
    * `id`: account id to unsubscribe from
* Response: JSON, returns a mastodon relationship object on success, otherwise returns `{"error": "error_msg"}`
* Example response:
```json
{
  "id": "abcdefg",
  "following": true,
  "followed_by": false,
  "blocking": false,
  "muting": false,
  "muting_notifications": false,
  "subscribing": false,
  "notifying": false,
  "requested": false,
  "domain_blocking": false,
  "showing_reblogs": true,
  "endorsed": false,
  "note": ""
}
```

## `/api/v1/pleroma/accounts/:id/favourites`
### Returns favorites timeline of any user
* Method `GET`
* Authentication: not required
* Params:
    * `id`: the id of the account for whom to return results
    * `limit`: optional, the number of records to retrieve
    * `since_id`: optional, returns results that are more recent than the specified id
    * `max_id`: optional, returns results that are older than the specified id
* Response: JSON, returns a list of Mastodon Status entities on success, otherwise returns `{"error": "error_msg"}`
* Example response:
```json
[
  {
    "account": {
      "id": "9hptFmUF3ztxYh3Svg",
      "url": "https://pleroma.example.org/users/nick2",
      "username": "nick2",
      ...
    },
    "application": {"name": "Web", "website": null},
    "bookmarked": false,
    "card": null,
    "content": "This is :moominmamma: note 0",
    "created_at": "2019-04-15T15:42:15.000Z",
    "emojis": [],
    "favourited": false,
    "favourites_count": 1,
    "id": "9hptFmVJ02khbzYJaS",
    "in_reply_to_account_id": null,
    "in_reply_to_id": null,
    "language": null,
    "media_attachments": [],
    "mentions": [],
    "muted": false,
    "pinned": false,
    "pleroma": {
      "content": {"text/plain": "This is :moominmamma: note 0"},
      "conversation_id": 13679,
      "local": true,
      "spoiler_text": {"text/plain": "2hu"}
    },
    "reblog": null,
    "reblogged": false,
    "reblogs_count": 0,
    "replies_count": 0,
    "sensitive": false,
    "spoiler_text": "2hu",
    "tags": [{"name": "2hu", "url": "/tag/2hu"}],
    "uri": "https://pleroma.example.org/objects/198ed2a1-7912-4482-b559-244a0369e984",
    "url": "https://pleroma.example.org/notice/9hptFmVJ02khbzYJaS",
    "visibility": "public"
  }
]
```


## `/api/v1/pleroma/accounts/:id/endorsements`
### Returns users endorsed by a user
* Method `GET`
* Authentication: not required
* Params:
    * `id`: the id of the account for whom to return results
* Response: JSON, returns a list of Mastodon Account entities

## `/api/v1/pleroma/accounts/update_*`
### Set and clear account avatar, banner, and background

- PATCH `/api/v1/pleroma/accounts/update_avatar`: Set/clear user avatar image
- PATCH `/api/v1/pleroma/accounts/update_banner`: Set/clear user banner image
- PATCH `/api/v1/pleroma/accounts/update_background`: Set/clear user background image

## `/api/v1/pleroma/accounts/confirmation_resend`
### Resend confirmation email
* Method `POST`
* Params:
    * `email`: email of that needs to be verified
* Authentication: not required
* Response: 204 No Content

## `/api/v1/pleroma/statuses/:id/quotes`
### Gets quotes for a given status
* Method `GET`
* Authentication: not required
* Params:
    * `id`: the id of the status
* Response: JSON, returns a list of Mastodon Status entities

## `GET /api/v1/pleroma/bookmark_folders`
### Gets user bookmark folders
* Authentication: required

* Response: JSON. Returns a list of bookmark folders.
* Example response:
```json
[
    {
        "id": "9umDrYheeY451cQnEe",
        "name": "Read later",
        "emoji": "🕓",
        "emoji_url": null
    }
]
```

## `POST /api/v1/pleroma/bookmark_folders`
### Creates a bookmark folder
* Authentication: required

* Params:
    * `name`: folder name
    * `emoji`: folder emoji (optional)
* Response: JSON. Returns a single bookmark folder.

## `PATCH /api/v1/pleroma/bookmark_folders/:id`
### Updates a bookmark folder
* Authentication: required

* Params:
    * `id`: folder id
    * `name`: folder name (optional)
    * `emoji`: folder emoji (optional)
* Response: JSON. Returns a single bookmark folder.

## `DELETE /api/v1/pleroma/bookmark_folders/:id`
### Deletes a bookmark folder
* Authentication: required

* Params:
    * `id`: folder id
* Response: JSON. Returns a single bookmark folder.

## `/api/v1/pleroma/mascot`
### Gets user mascot image
* Method `GET`
* Authentication: required

* Response: JSON. Returns a mastodon media attachment entity.
* Example response:
```json
{
    "id": "abcdefg",
    "url": "https://pleroma.example.org/media/abcdefg.png",
    "type": "image",
    "pleroma": {
        "mime_type": "image/png"
    }
}
```

### Updates user mascot image
* Method `PUT`
* Authentication: required
* Params:
    * `file`: Multipart image
* Response: JSON. Returns a mastodon media attachment entity
  when successful, otherwise returns HTTP 415 `{"error": "error_msg"}`
* Example response:
```json
{
    "id": "abcdefg",
    "url": "https://pleroma.example.org/media/abcdefg.png",
    "type": "image",
    "pleroma": {
        "mime_type": "image/png"
    }
}
```
* Note: Behaves exactly the same as `POST /api/v1/upload`.
  Can only accept images - any attempt to upload non-image files will be met with `HTTP 415 Unsupported Media Type`.

## `/api/pleroma/notification_settings`
### Updates user notification settings
* Method `PUT`
* Authentication: required
* Params:
    * `block_from_strangers`: BOOLEAN field, blocks notifications from accounts you do not follow
    * `hide_notification_contents`: BOOLEAN field. When set to true, it removes the contents of a message from the push notification.
* Response: JSON. Returns `{"status": "success"}` if the update was successful, otherwise returns `{"error": "error_msg"}`

## `/api/v1/pleroma/healthcheck`
### Healthcheck endpoint with additional system data.
* Method `GET`
* Authentication: not required
* Params: none
* Response: JSON, statuses (200 - healthy, 503 unhealthy).
* Example response:
```json
{
  "pool_size": 0, # database connection pool
  "active": 0, # active processes
  "idle": 0, # idle processes
  "memory_used": 0.00, # Memory used
  "healthy": true, # Instance state
  "job_queue_stats": {} # Job queue stats
}
```

## `/api/pleroma/change_email`
### Change account email
* Method `POST`
* Authentication: required
* Params:
    * `password`: user's password
    * `email`: new email
* Response: JSON. Returns `{"status": "success"}` if the change was successful, `{"error": "[error message]"}` otherwise
* Note: Currently, Mastodon has no API for changing email. If they add it in future it might be incompatible with Pleroma.

## `/api/pleroma/move_account`
### Move account
* Method `POST`
* Authentication: required
* Params:
    * `password`: user's password
    * `target_account`: the nickname of the target account (e.g. `foo@example.org`)
* Response: JSON. Returns `{"status": "success"}` if the change was successful, `{"error": "[error message]"}` otherwise
* Note: This endpoint emits a `Move` activity to all followers of the current account. Some remote servers will automatically unfollow the current account and follow the target account upon seeing this, but this depends on the remote server implementation and cannot be guaranteed. For local followers , they will automatically unfollow and follow if and only if they have set the `allow_following_move` preference ("Allow auto-follow when following account moves").

## `/api/pleroma/aliases`
### Get aliases of the current account
* Method `GET`
* Authentication: required
* Response: JSON. Returns `{"aliases": [alias, ...]}`, where `alias` is the nickname of an alias, e.g. `foo@example.org`.

### Add alias to the current account
* Method `PUT`
* Authentication: required
* Params:
    * `alias`: the nickname of the alias to add, e.g. `foo@example.org`.
* Response: JSON. Returns `{"status": "success"}` if the change was successful, `{"error": "[error message]"}` otherwise

### Delete alias from the current account
* Method `DELETE`
* Authentication: required
* Params:
    * `alias`: the nickname of the alias to delete, e.g. `foo@example.org`.
* Response: JSON. Returns `{"status": "success"}` if the change was successful, `{"error": "[error message]"}` otherwise

## `/api/v1/pleroma/remote_interaction`
## Interact with profile or status from remote account
* Metod `POST`
* Authentication: not required
* Params:
    * `ap_id`: Profile or status ActivityPub ID
    * `profile`: Remote profile webfinger
* Response: JSON. Returns `{"url": "[redirect url]"}` on success, `{"error": "[error message]"}` otherwise

# Pleroma Conversations

Pleroma Conversations have the same general structure that Mastodon Conversations have. The behavior differs in the following ways when using these endpoints:

1. Pleroma Conversations never add or remove recipients, unless explicitly changed by the user.
2. Pleroma Conversations statuses can be requested by Conversation id.
3. Pleroma Conversations can be replied to.

Conversations have the additional field `recipients` under the `pleroma` key. This holds a list of all the accounts that will receive a message in this conversation.

The status posting endpoint takes an additional parameter, `in_reply_to_conversation_id`, which, when set, will set the visibility to direct and address only the people who are the recipients of that Conversation.

⚠ Conversation IDs can be found in direct messages with the `pleroma.direct_conversation_id` key, do not confuse it with `pleroma.conversation_id`.

## `GET /api/v1/pleroma/conversations/:id/statuses`
### Timeline for a given conversation
* Method `GET`
* Authentication: required
* Params: Like other timelines
* Response: JSON, statuses (200 - healthy, 503 unhealthy).

## `GET /api/v1/pleroma/conversations/:id`
### The conversation with the given ID.
* Method `GET`
* Authentication: required
* Params: None
* Response: JSON, statuses (200 - healthy, 503 unhealthy).

## `PATCH /api/v1/pleroma/conversations/:id`
### Update a conversation. Used to change the set of recipients.
* Method `PATCH`
* Authentication: required
* Params:
    * `recipients`: A list of ids of users that should receive posts to this conversation. This will replace the current list of recipients, so submit the full list. The owner of owner of the conversation will always be part of the set of recipients, though.
* Response: JSON, statuses (200 - healthy, 503 unhealthy)

## `POST /api/v1/pleroma/conversations/read`
### Marks all user's conversations as read.
* Method `POST`
* Authentication: required
* Params: None
* Response: JSON, returns a list of Mastodon Conversation entities that were marked as read (200 - healthy, 503 unhealthy).

## `GET /api/v1/pleroma/emoji/pack?name=:name`

### Get pack.json for the pack

* Method `GET`
* Authentication: not required
* Params:
  * `page`: page number for files (default 1)
  * `page_size`: page size for files (default 30)
* Response: JSON, pack json with `files`, `files_count` and `pack` keys with 200 status or 404 if the pack does not exist.

```json
{
  "files": {...},
  "files_count": 0, // emoji count in pack
  "pack": {...}
}
```

## `POST /api/v1/pleroma/emoji/pack?name=:name`

### Creates an empty pack

* Method `POST`
* Authentication: required (admin)
* Params:
  * `name`: pack name
* Response: JSON, "ok" and 200 status or 409 if the pack with that name already exists

## `PATCH /api/v1/pleroma/emoji/pack?name=:name`

### Updates (replaces) pack metadata

* Method `PATCH`
* Authentication: required (admin)
* Params:
  * `name`: pack name
  * `metadata`: metadata to replace the old one
    * `license`: Pack license
    * `homepage`: Pack home page url
    * `description`: Pack description
    * `fallback-src`: Fallback url to download pack from
    * `fallback-src-sha256`: SHA256 encoded for fallback pack archive
    * `share-files`: is pack allowed for sharing (boolean)
* Response: JSON, updated "metadata" section of the pack and 200 status or 400 if there was a
  problem with the new metadata (the error is specified in the "error" part of the response JSON)

## `DELETE /api/v1/pleroma/emoji/pack?name=:name`

### Delete a custom emoji pack

* Method `DELETE`
* Authentication: required (admin)
* Params:
  * `name`: pack name
* Response: JSON, "ok" and 200 status or 500 if there was an error deleting the pack

## `GET /api/v1/pleroma/emoji/packs/import`

### Imports packs from filesystem

* Method `GET`
* Authentication: required (admin)
* Params: None
* Response: JSON, returns a list of imported packs.

## `GET /api/v1/pleroma/emoji/packs/remote`

### Make request to another instance for packs list

* Method `GET`
* Authentication: required (admin)
* Params:
  * `url`: url of the instance to get packs from
  * `page`: page number for packs (default 1)
  * `page_size`: page size for packs (default 50)
* Response: JSON with the pack list, hashmap with pack name and pack contents

## `POST /api/v1/pleroma/emoji/packs/download`

### Download pack from another instance

* Method `POST`
* Authentication: required (admin)
* Params:
  * `url`: url of the instance to download from
  * `name`: pack to download from that instance
  * `as`: (*optional*) name how to save pack
* Response: JSON, "ok" with 200 status if the pack was downloaded, or 500 if there were
  errors downloading the pack

## `POST /api/v1/pleroma/emoji/packs/files?name=:name`

### Add new file to the pack

* Method `POST`
* Authentication: required (admin)
* Params:
  * `name`: pack name
  * `file`: file needs to be uploaded with the multipart request or link to remote file.
  * `shortcode`: (*optional*) shortcode for new emoji, must be unique for all emoji. If not sended, shortcode will be taken from original filename.
  * `filename`: (*optional*) new emoji file name. If not specified will be taken from original filename.
* Response: JSON, list of files for updated pack (hashmap -> shortcode => filename) with status 200, either error status with error message.

## `PATCH /api/v1/pleroma/emoji/packs/files?name=:name`

### Update emoji file from pack

* Method `PATCH`
* Authentication: required (admin)
* Params:
  * `name`: pack name
  * `shortcode`: emoji file shortcode
  * `new_shortcode`: new emoji file shortcode
  * `new_filename`: new filename for emoji file
  * `force`: (*optional*) with true value to overwrite existing emoji with new shortcode
* Response: JSON, list with updated files for updated pack (hashmap -> shortcode => filename) with status 200, either error status with error message.

## `DELETE /api/v1/pleroma/emoji/packs/files?name=:name`

### Delete emoji file from pack

* Method `DELETE`
* Authentication: required (admin)
* Params:
  * `name`: pack name
  * `shortcode`: emoji file shortcode
* Response: JSON, list with updated files for updated pack (hashmap -> shortcode => filename) with status 200, either error status with error message.

## `GET /api/v1/pleroma/emoji/packs`

### Lists local custom emoji packs

* Method `GET`
* Authentication: not required
* Params:
  * `page`: page number for packs (default 1)
  * `page_size`: page size for packs (default 50)
* Response: `packs` key with JSON hashmap of pack name to pack contents and `count` key for count of packs.

```json
{
  "packs": {
    "pack_name": {...}, // pack contents
    ...
  },
  "count": 0 // packs count
}
```

## `GET /api/v1/pleroma/emoji/packs/archive?name=:name`

### Requests a local pack archive from the instance

* Method `GET`
* Authentication: not required
* Params:
  * `name`: pack name
* Response: the archive of the pack with a 200 status code, 403 if the pack is not set as shared,
  404 if the pack does not exist

## `GET /api/v1/pleroma/accounts/:id/scrobbles`

Audio scrobbling in Pleroma is **deprecated**.

### Requests a list of current and recent Listen activities for an account
* Method `GET`
* Authentication: not required
* Params: None
* Response: An array of media metadata entities.
* Example response:
```json
[
   {
       "account": {...},
       "id": "1234",
       "title": "Some Title",
       "artist": "Some Artist",
       "album": "Some Album",
       "length": 180000,
       "created_at": "2019-09-28T12:40:45.000Z"
   }
]
```

## `POST /api/v1/pleroma/scrobble`

Audio scrobbling in Pleroma is **deprecated**.

### Creates a new Listen activity for an account
* Method `POST`
* Authentication: required
* Params:
  * `title`: the title of the media playing
  * `album`: the album of the media playing [optional]
  * `artist`: the artist of the media playing [optional]
  * `length`: the length of the media playing [optional]
* Response: the newly created media metadata entity representing the Listen activity

# Emoji Reactions

Emoji reactions work a lot like favourites do. They make it possible to react to a post with a single emoji character. To detect the presence of this feature, you can check `pleroma_emoji_reactions` entry in the features list of nodeinfo.

## `PUT /api/v1/pleroma/statuses/:id/reactions/:emoji`
### React to a post with a unicode emoji
* Method: `PUT`
* Authentication: required
* Params: `emoji`: A unicode RGI emoji or a regional indicator
* Response: JSON, the status.

## `DELETE /api/v1/pleroma/statuses/:id/reactions/:emoji`
### Remove a reaction to a post with a unicode emoji
* Method: `DELETE`
* Authentication: required
* Params: `emoji`: A unicode RGI emoji or a regional indicator
* Response: JSON, the status.

## `GET /api/v1/pleroma/statuses/:id/reactions`
### Get an object of emoji to account mappings with accounts that reacted to the post
* Method: `GET`
* Authentication: optional
* Params: None
* Response: JSON, a list of emoji/account list tuples, sorted by emoji insertion date, in ascending order, e.g, the first emoji in the list is the oldest.
* Example Response:
```json
[
  {"name": "😀", "count": 2, "me": true, "accounts": [{"id" => "xyz.."...}, {"id" => "zyx..."}]},
  {"name": "☕", "count": 1, "me": false, "accounts": [{"id" => "abc..."}]}
]
```

## `GET /api/v1/pleroma/statuses/:id/reactions/:emoji`
### Get an object of emoji to account mappings with accounts that reacted to the post for a specific emoji
* Method: `GET`
* Authentication: optional
* Params: None
* Response: JSON, a list of emoji/account list tuples
* Example Response:
```json
[
  {"name": "😀", "count": 2, "me": true, "accounts": [{"id" => "xyz.."...}, {"id" => "zyx..."}]}
]
```

## `POST /api/v1/pleroma/backups`
### Create a user backup archive

* Method: `POST`
* Authentication: required
* Params: none
* Response: JSON
* Example response:

```json
[{
    "content_type": "application/zip",
    "file_size": 0,
    "inserted_at": "2020-09-10T16:18:03.000Z",
    "processed": false,
    "url": "https://example.com/media/backups/archive-foobar-20200910T161803-QUhx6VYDRQ2wfV0SdA2Pfj_2CLM_ATUlw-D5l5TJf4Q.zip"
}]
```

## `GET /api/v1/pleroma/backups`
### Lists user backups

* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response:

```json
[{
    "content_type": "application/zip",
    "file_size": 55457,
    "inserted_at": "2020-09-10T16:18:03.000Z",
    "processed": true,
    "url": "https://example.com/media/backups/archive-foobar-20200910T161803-QUhx6VYDRQ2wfV0SdA2Pfj_2CLM_ATUlw-D5l5TJf4Q.zip"
}]
```

## `GET /api/oauth_tokens`
### Retrieve a list of active sessions for the user
* Method: `GET`
* Authentication: required
* Params: none
* Response: JSON
* Example response:

```json
[
  {
    "app_name": "Pleroma FE",
    "id": 9275,
    "valid_until": "2121-11-24T15:51:08.234234"
  },
  {
    "app_name": "Patron",
    "id": 8805,
    "valid_until": "2121-10-26T18:09:59.857150"
  },
  {
    "app_name": "Soapbox FE",
    "id": 9727,
    "valid_until": "2121-12-25T16:52:39.692877"
  }
]
```

## `DELETE /api/oauth_tokens/:id`
### Revoke a user session by its ID
* Method: `DELETE`
* Authentication: required
* Params: none
* Response: HTTP 200 on success, 500 on error

## `/api/v1/pleroma/settings/:app`
### Gets settings for some application
* Method `GET`
* Authentication: `read:accounts`

* Response: JSON. The settings for that application, or empty object if there is none.
* Example response:
```json
{
  "some key": "some value"
}
```

### Updates settings for some application
* Method `PATCH`
* Authentication: `write:accounts`
* Request body: JSON object. The object will be merged recursively with old settings. If some field is set to null, it is removed.
* Example request:
```json
{
  "some key": "some value",
  "key to remove": null,
  "nested field": {
    "some key": "some value",
    "key to remove": null
  }
}
```
* Response: JSON. Updated (merged) settings for that application.
* Example response:
```json
{
  "some key": "some value",
  "nested field": {
    "some key": "some value",
  }
}
```
