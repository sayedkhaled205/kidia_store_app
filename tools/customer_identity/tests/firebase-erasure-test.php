<?php

declare(strict_types=1);

require __DIR__ . '/../backend/app/Services/FirebaseIdentityErasureException.php';
require __DIR__ . '/../backend/app/Services/FirebaseIdentityErasure.php';

use App\Services\FirebaseIdentityErasure;
use App\Services\FirebaseIdentityErasureException;

const TEST_PROJECT = 'synthetic-proj-1';

/** @var list<string> */
$failures = [];

/**
 * Builds a transport that replays a queue of {status,body} responses and
 * records every (method,url,json) call it receives.
 *
 * @param list<array{status:int,body:array}> $responses
 * @param list<array{method:string,url:string,json:array}> $calls
 */
function makeTransport(array $responses, array &$calls): callable
{
    return static function (string $method, string $url, array $json) use (&$responses, &$calls): array {
        $calls[] = ['method' => $method, 'url' => $url, 'json' => $json];
        if ($responses === []) {
            throw new \RuntimeException('transport queue exhausted');
        }
        return array_shift($responses);
    };
}

function check(string $name, bool $condition, array &$failures): void
{
    if (!$condition) {
        $failures[] = $name;
        echo "FAIL: {$name}\n";
    } else {
        echo "PASS: {$name}\n";
    }
}

function expectException(callable $fn, int $expectedCode): ?string
{
    try {
        $fn();
    } catch (FirebaseIdentityErasureException $e) {
        return $e->getCode() === $expectedCode ? null : 'wrong code: ' . $e->getCode();
    }
    return 'no exception thrown';
}

// --- 1. exact host/path/method/body on lookup, project fixed not from caller ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-1', 'createdAt' => '1000']]]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$snapshot = $client->lookup('uid-1');
check('lookup: host/path/method exact', $calls[0]['method'] === 'POST'
    && $calls[0]['url'] === 'https://identitytoolkit.googleapis.com/v1/projects/' . TEST_PROJECT . '/accounts:lookup', $failures);
check('lookup: body shape exact', $calls[0]['json'] === ['localId' => ['uid-1']], $failures);
check('lookup: snapshot returned', $snapshot === ['uid' => 'uid-1', 'created_at' => '1000'], $failures);

// --- 2. project never supplied by caller; uid cannot change project in URL ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => []]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$client->lookup('other-project/accounts:lookup#x');
check('project fixed regardless of uid content', strpos($calls[0]['url'], TEST_PROJECT) !== false
    && substr_count($calls[0]['url'], '/accounts:lookup') === 1, $failures);

// --- 3. wrong/foreign UID in response ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'different-uid', 'createdAt' => '1000']]]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$err = expectException(fn() => $client->lookup('uid-1'), FirebaseIdentityErasureException::FOREIGN_IDENTITY);
check('foreign localId rejected', $err === null, $failures);

// --- 4. malformed createdAt ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-1', 'createdAt' => 'not-a-number']]]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$err = expectException(fn() => $client->lookup('uid-1'), FirebaseIdentityErasureException::LOOKUP_MALFORMED);
check('malformed createdAt rejected', $err === null, $failures);

// --- 5. foreign/invalid project at construction rejected ---
try {
    new FirebaseIdentityErasure('NOT_VALID_PROJECT', static fn() => ['status' => 200, 'body' => []]);
    check('invalid project id rejected', false, $failures);
} catch (FirebaseIdentityErasureException $e) {
    check('invalid project id rejected', $e->getCode() === FirebaseIdentityErasureException::INVALID_PROJECT, $failures);
}

// --- 6. absent identity: no delete call made, erase returns absent ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => []]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$result = $client->erase('uid-absent', '1000');
check('absent identity: erase returns absent', $result === ['status' => 'absent'], $failures);
check('absent identity: only lookup called, no delete', count($calls) === 1, $failures);

// --- 7. exact generation match -> delete -> absence confirmed ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-2', 'createdAt' => '5000']]]],
    ['status' => 200, 'body' => []],
    ['status' => 200, 'body' => ['users' => []]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$result = $client->erase('uid-2', '5000');
check('full erase success: result absent', $result === ['status' => 'absent'], $failures);
check('full erase success: delete call exact', $calls[1]['method'] === 'POST'
    && $calls[1]['url'] === 'https://identitytoolkit.googleapis.com/v1/projects/' . TEST_PROJECT . '/accounts:delete'
    && $calls[1]['json'] === ['localId' => 'uid-2'], $failures);
check('full erase success: three calls made', count($calls) === 3, $failures);

// --- identity_changed: mismatched created_at -> no delete call ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-3', 'createdAt' => '5000']]]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$err = expectException(fn() => $client->erase('uid-3', '9999'), FirebaseIdentityErasureException::IDENTITY_CHANGED);
check('mismatched created_at rejected', $err === null, $failures);
check('mismatched created_at: no delete attempted', count($calls) === 1, $failures);

// --- 8. recreated UID after delete: second lookup still finds user ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-4', 'createdAt' => '5000']]]],
    ['status' => 200, 'body' => []],
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-4', 'createdAt' => '6000']]]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$err = expectException(fn() => $client->erase('uid-4', '5000'), FirebaseIdentityErasureException::ERASURE_UNCONFIRMED);
check('recreated UID treated as unconfirmed', $err === null, $failures);

// --- 9. provider delete failure (non-200, non-USER_NOT_FOUND) ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-5', 'createdAt' => '5000']]]],
    ['status' => 500, 'body' => ['error' => ['code' => 500, 'message' => 'INTERNAL']]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$err = expectException(fn() => $client->erase('uid-5', '5000'), FirebaseIdentityErasureException::DELETE_UNAVAILABLE);
check('provider delete failure sanitized', $err === null, $failures);

// --- 10. lookup failure (non-200) ---
$calls = [];
$transport = makeTransport([
    ['status' => 503, 'body' => []],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$err = expectException(fn() => $client->lookup('uid-6'), FirebaseIdentityErasureException::LOOKUP_UNAVAILABLE);
check('lookup failure sanitized', $err === null, $failures);

// --- 11. delete responds USER_NOT_FOUND -> treated as success if recheck absent ---
$calls = [];
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => 'uid-7', 'createdAt' => '5000']]]],
    ['status' => 400, 'body' => ['error' => ['code' => 400, 'message' => 'USER_NOT_FOUND']]],
    ['status' => 200, 'body' => ['users' => []]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$result = $client->erase('uid-7', '5000');
check('USER_NOT_FOUND on delete treated as absent after recheck', $result === ['status' => 'absent'], $failures);

// --- 12. unsafe UID with control characters rejected before any transport call ---
$calls = [];
$transport = makeTransport([], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$err = expectException(fn() => $client->lookup("uid\x00bad"), FirebaseIdentityErasureException::INVALID_UID);
check('control character UID rejected', $err === null, $failures);
check('control character UID: no transport call made', count($calls) === 0, $failures);

$err = expectException(fn() => $client->lookup(''), FirebaseIdentityErasureException::INVALID_UID);
check('empty UID rejected', $err === null, $failures);

$longUid = str_repeat('a', 129);
$err = expectException(fn() => $client->lookup($longUid), FirebaseIdentityErasureException::INVALID_UID);
check('oversized UID rejected', $err === null, $failures);

$invalidUtf8 = "uid-\xB1\xFF";
$err = expectException(fn() => $client->lookup($invalidUtf8), FirebaseIdentityErasureException::INVALID_UID);
check('invalid UTF-8 UID rejected', $err === null, $failures);

// --- 13. UID special characters stay in JSON body and cannot alter the URL ---
$calls = [];
$specialUid = 'uid/weird?x=1&y=2#frag "quote" \\back ünïcödé';
$transport = makeTransport([
    ['status' => 200, 'body' => ['users' => [['localId' => $specialUid, 'createdAt' => '1000']]]],
], $calls);
$client = new FirebaseIdentityErasure(TEST_PROJECT, $transport);
$client->lookup($specialUid);
check('special-char UID stays in JSON body verbatim', $calls[0]['json'] === ['localId' => [$specialUid]], $failures);
check('special-char UID: URL unaffected', $calls[0]['url'] === 'https://identitytoolkit.googleapis.com/v1/projects/' . TEST_PROJECT . '/accounts:lookup', $failures);

foreach ([null, 'malformed', ['unexpected' => []]] as $badUsers) {
    $calls = [];
    $client = new FirebaseIdentityErasure(TEST_PROJECT, makeTransport([
        ['status' => 200, 'body' => ['users' => $badUsers]],
    ], $calls));
    check('malformed users never proves absence', expectException(
        fn() => $client->lookup('uid-1'), FirebaseIdentityErasureException::LOOKUP_MALFORMED,
    ) === null, $failures);
}
$calls = [];
$client = new FirebaseIdentityErasure(TEST_PROJECT, makeTransport([
    ['status' => 200, 'body' => ['error' => ['message' => 'synthetic-private-detail']]],
], $calls));
check('error envelope never proves absence', expectException(fn() => $client->lookup('uid-1'), FirebaseIdentityErasureException::LOOKUP_MALFORMED) === null, $failures);
$client = new FirebaseIdentityErasure(TEST_PROJECT, static function () { throw new RuntimeException('synthetic-private-token'); });
try { $client->lookup('uid-1'); check('transport exception rejected', false, $failures); }
catch (FirebaseIdentityErasureException $error) {
    check('transport error sanitized without sensitive cause', !str_contains($error->getMessage(), 'private-token') && $error->getPrevious() === null, $failures);
}
check('project trailing newline rejected', expectException(fn() => new FirebaseIdentityErasure(TEST_PROJECT."\n", static fn() => []), FirebaseIdentityErasureException::INVALID_PROJECT) === null, $failures);
$client = new FirebaseIdentityErasure(TEST_PROJECT, static fn() => []);
check('Unicode control UID rejected', expectException(fn() => $client->lookup("uid\u{0085}"), FirebaseIdentityErasureException::INVALID_UID) === null, $failures);

foreach ([['unexpected' => 'pending'], ['permissions' => []], ['kind' => 'not-a-user-lookup']] as $unrelated) {
    $calls = [];
    $client = new FirebaseIdentityErasure(TEST_PROJECT, makeTransport([
        ['status' => 200, 'body' => $unrelated],
    ], $calls));
    check('unrelated 200 response cannot establish absence', expectException(fn() => $client->erase('uid-1', '12345'), FirebaseIdentityErasureException::LOOKUP_MALFORMED) === null, $failures);
    check('unrelated initial lookup cannot dispatch deletion', count($calls) === 1, $failures);
    $calls = [];
    $client = new FirebaseIdentityErasure(TEST_PROJECT, makeTransport([
        ['status' => 200, 'body' => ['users' => [['localId' => 'uid-1', 'createdAt' => '12345']]]],
        ['status' => 200, 'body' => []],
        ['status' => 200, 'body' => $unrelated],
    ], $calls));
    check('unrelated final lookup cannot confirm erasure', expectException(fn() => $client->erase('uid-1', '12345'), FirebaseIdentityErasureException::LOOKUP_MALFORMED) === null, $failures);
}
$calls = [];
$client = new FirebaseIdentityErasure(TEST_PROJECT, makeTransport([
    ['status' => 200, 'body' => ['kind' => 'identitytoolkit#GetAccountInfoResponse']],
], $calls));
check('documented legacy lookup kind permits omitted empty users', $client->lookup('uid-1') === null, $failures);

// --- summary ---
echo "\n" . count($failures) . ' failing checks out of recorded checks.' . "\n";

if ($failures !== []) {
    exit(1);
}

echo "All FirebaseIdentityErasure tests passed.\n";
exit(0);
