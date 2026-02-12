import Foundation

// MARK: - L10n — Centralized Localization Keys (Main App Target)

enum L10n {

    // MARK: - Common

    enum Common {
        static let cancel = String(localized: "common_cancel", defaultValue: "Cancel")
        static let delete = String(localized: "common_delete", defaultValue: "Delete")
        static let save = String(localized: "common_save", defaultValue: "Save")
        static let done = String(localized: "common_done", defaultValue: "Done")
        static let rename = String(localized: "common_rename", defaultValue: "Rename")
        static let tryAgain = String(localized: "common_try_again", defaultValue: "Try again")
        static let somethingWentWrong = String(localized: "common_something_went_wrong", defaultValue: "Something went wrong")
        static let actionCannotBeUndone = String(localized: "common_action_cannot_be_undone", defaultValue: "This action cannot be undone.")
    }

    // MARK: - Tabs

    enum Tab {
        static let notes = String(localized: "tab_notes", defaultValue: "Notes")
        static let record = String(localized: "tab_record", defaultValue: "Record")
        static let settings = String(localized: "tab_settings", defaultValue: "Settings")
    }

    // MARK: - App

    enum App {
        static let title = String(localized: "app_title", defaultValue: "DXWhisp")
        static let voiceNote = String(localized: "app_voice_note", defaultValue: "Voice Note")
        static let authenticateToView = String(localized: "app_authenticate_to_view", defaultValue: "Authenticate to view this note")
    }

    // MARK: - Recording

    enum Recording {
        static let tapToStart = String(localized: "recording_tap_to_start", defaultValue: "Tap to start recording")
        static let tapToStop = String(localized: "recording_tap_to_stop", defaultValue: "Tap to stop")
        static let processing = String(localized: "recording_processing", defaultValue: "Processing...")
        static let transcribing = String(localized: "recording_transcribing", defaultValue: "Transcribing your recording...")
        static let complete = String(localized: "recording_complete", defaultValue: "RECORDING COMPLETE")
        static let viewNote = String(localized: "recording_view_note", defaultValue: "View Note")
        static let newRecording = String(localized: "recording_new_recording", defaultValue: "New Recording")
        static let transcriptionFailed = String(localized: "recording_transcription_failed", defaultValue: "Transcription Failed")
        static let micRequired = String(localized: "recording_mic_required", defaultValue: "Microphone access required. Enable it in Settings → DXWhisp.")
        static let micDenied = String(localized: "recording_mic_denied", defaultValue: "Microphone access denied. Enable it in Settings → DXWhisp → Microphone.")
    }

    // MARK: - Notes List

    enum NotesList {
        static let searchPrompt = String(localized: "notes_list_search_prompt", defaultValue: "Search notes")
        static let emptyTitle = String(localized: "notes_list_empty_title", defaultValue: "No Notes Yet")
        static let emptySubtitle = String(localized: "notes_list_empty_subtitle", defaultValue: "Record your first voice note to get started")
        static let favorites = String(localized: "notes_list_favorites", defaultValue: "Favorites")
        static let allNotes = String(localized: "notes_list_all_notes", defaultValue: "All Notes")
        static let noMatchingNotes = String(localized: "notes_list_no_matching_notes", defaultValue: "No Matching Notes")
        static let noResults = String(localized: "notes_list_no_results", defaultValue: "No Results")
        static let noMatchTagsAndSearch = String(localized: "notes_list_no_match_tags_and_search", defaultValue: "No notes match the selected tags and search text.")
        static let noMatchTags = String(localized: "notes_list_no_match_tags", defaultValue: "No notes are tagged with the selected filter.\nAssign tags via long press on a note.")
        static let clearTagFilter = String(localized: "notes_list_clear_tag_filter", defaultValue: "Clear Tag Filter")
        static let clear = String(localized: "notes_list_clear", defaultValue: "Clear")
        static let selectAll = String(localized: "notes_list_select_all", defaultValue: "Select All")
        static let deselectAll = String(localized: "notes_list_deselect_all", defaultValue: "Deselect All")
        static let lock = String(localized: "notes_list_lock", defaultValue: "Lock")
        static let deleteAll = String(localized: "notes_list_delete_all", defaultValue: "Delete All")
        static let addToFavorites = String(localized: "notes_list_add_to_favorites", defaultValue: "Add to Favorites")
        static let removeFromFavorites = String(localized: "notes_list_remove_from_favorites", defaultValue: "Remove from Favorites")
        static let tags = String(localized: "notes_list_tags", defaultValue: "Tags")
        static let tag = String(localized: "notes_list_tag", defaultValue: "Tag")
        static let editTag = String(localized: "notes_list_edit_tag", defaultValue: "Edit Tag")
        static let deleteTag = String(localized: "notes_list_delete_tag", defaultValue: "Delete Tag")
        static let renameNote = String(localized: "notes_list_rename_note", defaultValue: "Rename Note")
        static let noteTitle = String(localized: "notes_list_note_title", defaultValue: "Note title")
        static let loadFailed = String(localized: "notes_list_load_failed", defaultValue: "We couldn't load your notes. Pull down to try again.")
        static let deleteFailed = String(localized: "notes_list_delete_failed", defaultValue: "We couldn't delete that note. Please try again.")
        static let updateFailed = String(localized: "notes_list_update_failed", defaultValue: "We couldn't update that note. Please try again.")
        static let renameFailed = String(localized: "notes_list_rename_failed", defaultValue: "We couldn't rename that note. Please try again.")
        static let tagUpdateFailed = String(localized: "notes_list_tag_update_failed", defaultValue: "Tag update failed.")
        static let tagDeleteFailed = String(localized: "notes_list_tag_delete_failed", defaultValue: "Failed to delete tag.")
        static let tagSaveFailed = String(localized: "notes_list_tag_save_failed", defaultValue: "Failed to save tag.")
        static let deleteAllConfirmMessage = String(localized: "notes_list_delete_all_confirm_message", defaultValue: "This will permanently delete all your notes and recordings.")

        static func noMatchSearch(_ text: String) -> String {
            String(localized: "No notes match \"\(text)\".")
        }

        static func deleteSelectedTitle(_ count: Int) -> String {
            String(localized: "Delete \(count) notes?")
        }

        static func deleteAllTitle(_ count: Int) -> String {
            String(localized: "Delete all \(count) notes?")
        }

        static func deleteCount(_ count: Int) -> String {
            String(localized: "Delete (\(count))")
        }

        static func lockFailed(_ count: Int) -> String {
            String(localized: "Failed to lock \(count) note(s).")
        }

        static func unlockFailed(_ count: Int) -> String {
            String(localized: "Failed to unlock \(count) note(s).")
        }

        static func bulkDeleteFailed(_ count: Int) -> String {
            String(localized: "\(count) note(s) couldn't be deleted. Please try again.")
        }

        static func tagUpdateFailedCount(_ count: Int) -> String {
            String(localized: "Tag update failed for \(count) note(s).")
        }
    }

    // MARK: - Note Detail

    enum NoteDetail {
        static let deleteNote = String(localized: "note_detail_delete_note", defaultValue: "Delete Note?")
        static let lockNote = String(localized: "note_detail_lock_note", defaultValue: "Lock Note")
        static let unlockNote = String(localized: "note_detail_unlock_note", defaultValue: "Unlock Note")
        static let share = String(localized: "note_detail_share", defaultValue: "Share")
        static let noteLocked = String(localized: "note_detail_note_locked", defaultValue: "This note is locked")
        static let authenticate = String(localized: "note_detail_authenticate", defaultValue: "Authenticate")
        static let reExtracting = String(localized: "note_detail_re_extracting", defaultValue: "Re-extracting insights...")
        static let transcription = String(localized: "note_detail_transcription", defaultValue: "Transcription")
        static let summary = String(localized: "note_detail_summary", defaultValue: "Summary")
        static let actionItems = String(localized: "note_detail_action_items", defaultValue: "Action Items")
        static let datesAndEvents = String(localized: "note_detail_dates_and_events", defaultValue: "Dates & Events")
        static let keyPoints = String(localized: "note_detail_key_points", defaultValue: "Key Points")
        static let events = String(localized: "note_detail_events", defaultValue: "Events")
        static let reminders = String(localized: "note_detail_reminders", defaultValue: "Reminders")
        static let calendar = String(localized: "note_detail_calendar", defaultValue: "Calendar")
        static let saveFailed = String(localized: "note_detail_save_failed", defaultValue: "We couldn't save that change. Please try again.")
        static let deleteFailed = String(localized: "note_detail_delete_failed", defaultValue: "We couldn't delete this note. Please try again.")
        static let exportRemindersFailed = String(localized: "note_detail_export_reminders_failed", defaultValue: "We couldn't add that to Reminders. Check that Reminders is allowed in Settings → DXWhisp and try again.")
        static let exportCalendarFailed = String(localized: "note_detail_export_calendar_failed", defaultValue: "We couldn't add that to Calendar. Check that Calendar is allowed in Settings → DXWhisp and try again.")
        static let authFailed = String(localized: "note_detail_auth_failed", defaultValue: "Authentication was not successful.")
        static let lockFailed = String(localized: "note_detail_lock_failed", defaultValue: "We couldn't update the lock. Please try again.")
        static let playbackScrubber = String(localized: "note_detail_playback_scrubber", defaultValue: "Playback position")
        static let play = String(localized: "note_detail_play", defaultValue: "Play")
        static let pause = String(localized: "note_detail_pause", defaultValue: "Pause")

        static func saveTranscriptFailed(_ message: String) -> String {
            String(localized: "Couldn't save transcript: \(message)")
        }

        static func reExtractFailed(_ message: String) -> String {
            String(localized: "Couldn't re-extract insights: \(message)")
        }

        static func saveInsightsFailed(_ message: String) -> String {
            String(localized: "Couldn't save insights: \(message)")
        }
    }

    // MARK: - Settings

    enum Settings {
        static let integrations = String(localized: "settings_integrations", defaultValue: "INTEGRATIONS")
        static let about = String(localized: "settings_about", defaultValue: "ABOUT")
        static let autoExportActionItems = String(localized: "settings_auto_export_action_items", defaultValue: "Auto-Export Action Items")
        static let autoExportEvents = String(localized: "settings_auto_export_events", defaultValue: "Auto-Export Events")
        static let developer = String(localized: "settings_developer", defaultValue: "Developer")
        static let privacyPolicy = String(localized: "settings_privacy_policy", defaultValue: "Privacy Policy")
        static let termsOfService = String(localized: "settings_terms_of_service", defaultValue: "Terms of Service")

        static func version(_ v: String) -> String {
            String(localized: "Version \(v)")
        }
    }

    // MARK: - Integrations

    enum Integrations {
        static let title = String(localized: "integrations_title", defaultValue: "Integrations")
        static let reminders = String(localized: "integrations_reminders", defaultValue: "REMINDERS")
        static let calendarSection = String(localized: "integrations_calendar", defaultValue: "CALENDAR")
        static let autoExportActionItems = String(localized: "integrations_auto_export_action_items", defaultValue: "Auto-Export Action Items")
        static let autoExportActionItemsSubtitle = String(localized: "integrations_auto_export_action_items_subtitle", defaultValue: "Automatically export action items to Reminders")
        static let autoExportEvents = String(localized: "integrations_auto_export_events", defaultValue: "Auto-Export Events")
        static let autoExportEventsSubtitle = String(localized: "integrations_auto_export_events_subtitle", defaultValue: "Automatically export events to Calendar")
    }

    // MARK: - Tag Editor

    enum TagEditor {
        static let newTag = String(localized: "tag_editor_new_tag", defaultValue: "New Tag")
        static let editTag = String(localized: "tag_editor_edit_tag", defaultValue: "Edit Tag")
        static let tagName = String(localized: "tag_editor_tag_name", defaultValue: "Tag Name")
        static let enterTagName = String(localized: "tag_editor_enter_tag_name", defaultValue: "Enter tag name")
        static let preview = String(localized: "tag_editor_preview", defaultValue: "Preview")
        static let name = String(localized: "tag_editor_name", defaultValue: "NAME")
        static let color = String(localized: "tag_editor_color", defaultValue: "COLOR")
    }

    // MARK: - Subscription

    enum Subscription {
        static let unlockPro = String(localized: "subscription_unlock_pro", defaultValue: "Unlock DXWhisp Pro")
        static let subtitle = String(localized: "subscription_subtitle", defaultValue: "Unlimited recordings, AI insights, and more")
        static let subscribe = String(localized: "subscription_subscribe", defaultValue: "Subscribe")
        static let restorePurchases = String(localized: "subscription_restore_purchases", defaultValue: "Restore Purchases")
        static let save40 = String(localized: "subscription_save_40", defaultValue: "Save 40%")
        static let purchasePending = String(localized: "subscription_purchase_pending", defaultValue: "Your purchase is pending approval.")
        static let noActiveSubscription = String(localized: "subscription_no_active_subscription", defaultValue: "No active subscription found. If you recently purchased, it may take a moment to activate.")
        static let pro = String(localized: "subscription_pro", defaultValue: "PRO")
        static let manageSub = String(localized: "subscription_manage", defaultValue: "Manage Subscription")
        static let upgrade = String(localized: "subscription_upgrade", defaultValue: "Upgrade to Pro")
        static let upgradeSubtitle = String(localized: "subscription_upgrade_subtitle", defaultValue: "Unlimited recordings, AI insights, auto-export, and more")
        static let activeSubscription = String(localized: "subscription_active", defaultValue: "Active Subscription")

        // Feature list
        static let featureUnlimitedRecordings = String(localized: "subscription_feature_unlimited_recordings", defaultValue: "Unlimited recordings")
        static let featureSpeakerDetection = String(localized: "subscription_feature_speaker_detection", defaultValue: "Speaker detection")
        static let featureAIInsights = String(localized: "subscription_feature_ai_insights", defaultValue: "AI-powered insights")
        static let featureAutoExport = String(localized: "subscription_feature_auto_export", defaultValue: "Auto-export to Reminders & Calendar")
        static let featureUnlimitedTags = String(localized: "subscription_feature_unlimited_tags", defaultValue: "Unlimited tags")
        static let featureBiometricLock = String(localized: "subscription_feature_biometric_lock", defaultValue: "Biometric lock")

        static func freeRecordingsRemaining(_ count: Int) -> String {
            String(localized: "\(count) free recording(s) remaining this month")
        }
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let getStarted = String(localized: "onboarding_get_started", defaultValue: "Get Started")
        static let continueButton = String(localized: "onboarding_continue", defaultValue: "Continue")
        static let skip = String(localized: "onboarding_skip", defaultValue: "Skip")
        static let recordAnythingTitle = String(localized: "onboarding_record_anything_title", defaultValue: "Record Anything")
        static let recordAnythingSubtitle = String(localized: "onboarding_record_anything_subtitle", defaultValue: "Capture meetings, ideas, or random thoughts. Watch your voice come alive with a real-time waveform.")
        static let speakerDetectionTitle = String(localized: "onboarding_speaker_detection_title", defaultValue: "Know Who Said What")
        static let speakerDetectionSubtitle = String(localized: "onboarding_speaker_detection_subtitle", defaultValue: "Transcription with speaker detection. DXWhisp identifies turns in conversation so you never lose track.")
        static let insightsTitle = String(localized: "onboarding_insights_title", defaultValue: "Never Miss a Thing")
        static let insightsSubtitle = String(localized: "onboarding_insights_subtitle", defaultValue: "Action items go to Reminders. Dates go to Calendar. Key points are summarized. Automatically.")
        static let securityTitle = String(localized: "onboarding_security_title", defaultValue: "Private & Secure")
        static let securitySubtitle = String(localized: "onboarding_security_subtitle", defaultValue: "Your voice notes are encrypted and protected with Face ID. Your data, your control.")
    }
}
