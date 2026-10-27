# One-click design publication

The existing Publish dialog now checks open/cached design editors as well as the saved server draft. Confirmation saves changed editors through their existing submit path, waits for canonical save receipts, then re-fetches the protected publish snapshot. Opening or cancelling the dialog makes no writes.

Untouched prewarmed forms are not saved. Home saves first because shared page controls are stored alongside Home settings. Invalid inputs, incomplete hydration, overlapping manual saves, a changed server page, a missing/rejected receipt, document/store replacement, or late restored drafts stop publication. An uncertain editor save requires a reload instead of replaying a potentially committed Home creation. Network waits are bounded, and locks are released on failure. Server revision/digest conflict checks remain in use.

This coordinates supported design data; it does not enable arbitrary native code or SDK updates. The existing installed-app compatibility boundary remains unchanged. The extra server read detects a page already changed in another session; the pre-existing settings PUT is not an atomic compare-and-swap API.

## Verification

```
node --test tool/builder-assets/live-design-publish.test.cjs tool/builder-assets/publish-edits.test.cjs
node tools/live_ui_controls/page-controls.test.cjs
node tools/live_ui_controls/page-controls-runtime.test.cjs
```

## Deployment

Use `publish-edits.py <builder-root> <current-index-sha256>` to stage versioned assets and a review page. This patches the current central/frame sources at checked integration points and retains every unrelated byte. Review before activation. Pass the returned exact version as `--activate <version>`; activation verifies every original and staged hash before switching the index atomically. A changed asset requires fresh reconciliation. The saved index in the reported backup directory is the rollback pointer.

Do not write another chat's working tree or overwrite a live index from an older snapshot. Merchant settings are not part of this deployment. Verify real editor hydration and draft detection without publishing unrequested test data to customers.
