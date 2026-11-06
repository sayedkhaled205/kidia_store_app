<?php

declare(strict_types=1);

namespace App\Services;

/**
 * Minimal client for confirming erasure of a single Firebase Auth identity.
 *
 * The Firebase Auth REST API has no conditional "delete if generation
 * matches" operation, so this class approximates one by: looking up the
 * current record, comparing created_at as a generation token, deleting,
 * then re-confirming absence. A trusted, authenticated caller (a
 * configured deletion worker) must own the decision to erase; this class
 * never establishes authorization, screens, or credentials itself. Because
 * app-controlled users cannot choose or reuse Firebase UIDs, a matching
 * created_at is sufficient evidence that the same identity is being acted
 * upon. Erasing the Firebase identity does not, by itself, revoke any
 * upstream provider (e.g. Apple) authorization grant.
 */
final class FirebaseIdentityErasure
{
    private const HOST = 'https://identitytoolkit.googleapis.com';
    private const PROJECT_PATTERN = '/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/D';
    private const MAX_UID_CHARS = 128;
    private const USER_NOT_FOUND = 'USER_NOT_FOUND';

    private string $projectId;

    /** @var callable(string,string,array):array{status:int,body:array} */
    private $transport;

    public function __construct(string $projectId, callable $transport)
    {
        if (preg_match(self::PROJECT_PATTERN, $projectId) !== 1) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::INVALID_PROJECT);
        }

        $this->projectId = $projectId;
        $this->transport = $transport;
    }

    /**
     * @return array{uid:string,created_at:string}|null
     */
    public function lookup(string $uid): ?array
    {
        $this->assertValidUid($uid);

        $response = $this->call('accounts:lookup', ['localId' => [$uid]]);

        if ($response['status'] !== 200) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_UNAVAILABLE);
        }

        if (array_diff(array_keys($response['body']), ['kind', 'users'])
            || (array_key_exists('kind', $response['body'])
                && $response['body']['kind'] !== 'identitytoolkit#GetAccountInfoResponse')) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_MALFORMED);
        }
        $users = array_key_exists('users', $response['body']) ? $response['body']['users'] : [];
        if (!is_array($users) || !array_is_list($users)) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_MALFORMED);
        }
        if ($users === []) {
            return null;
        }

        if (count($users) !== 1) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_MALFORMED);
        }

        $user = $users[0];

        if (!is_array($user) || !isset($user['localId']) || !is_string($user['localId'])) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_MALFORMED);
        }

        if (!hash_equals($uid, $user['localId'])) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::FOREIGN_IDENTITY);
        }

        $createdAt = $user['createdAt'] ?? null;

        if (!is_string($createdAt) || preg_match('/^[0-9]{1,20}$/D', $createdAt) !== 1) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_MALFORMED);
        }

        return ['uid' => $uid, 'created_at' => $createdAt];
    }

    /**
     * @return array{status:'absent'}
     */
    public function erase(string $uid, string $expectedCreatedAt): array
    {
        $this->assertValidUid($uid);

        if (preg_match('/^[0-9]{1,20}$/D', $expectedCreatedAt) !== 1) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::INVALID_CREATED_AT);
        }

        $before = $this->lookup($uid);

        if ($before === null) {
            return ['status' => 'absent'];
        }

        if (!hash_equals($expectedCreatedAt, $before['created_at'])) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::IDENTITY_CHANGED);
        }

        $deleteResponse = $this->call('accounts:delete', ['localId' => $uid]);

        if (!$this->isAcceptedDeleteResponse($deleteResponse)) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::DELETE_UNAVAILABLE);
        }

        $after = $this->lookup($uid);

        if ($after !== null) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::ERASURE_UNCONFIRMED);
        }

        return ['status' => 'absent'];
    }

    /**
     * @param array{status:int,body:array} $response
     */
    private function isAcceptedDeleteResponse(array $response): bool
    {
        if ($response['status'] === 200) {
            return true;
        }

        $errorMessage = $response['body']['error']['message'] ?? null;

        return $response['status'] === 400
            && ($response['body']['error']['code'] ?? null) === 400
            && is_string($errorMessage) && $errorMessage === self::USER_NOT_FOUND;
    }

    /**
     * @return array{status:int,body:array}
     */
    private function call(string $operation, array $json): array
    {
        $url = self::HOST . '/v1/projects/' . $this->projectId . '/' . $operation;

        try {
            $response = ($this->transport)('POST', $url, $json);
        } catch (\Throwable) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_UNAVAILABLE);
        }

        if (!is_array($response) || !isset($response['status'], $response['body'])
            || !is_int($response['status']) || !is_array($response['body'])
        ) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::LOOKUP_UNAVAILABLE);
        }

        return $response;
    }

    private function assertValidUid(string $uid): void
    {
        if ($uid === '' || strlen($uid) > self::MAX_UID_CHARS * 4) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::INVALID_UID);
        }

        if (preg_match('//u', $uid) !== 1) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::INVALID_UID);
        }

        if (preg_match('/\p{Cc}/u', $uid) === 1) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::INVALID_UID);
        }

        if (preg_match_all('/./us', $uid) > self::MAX_UID_CHARS) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::INVALID_UID);
        }
    }
}
