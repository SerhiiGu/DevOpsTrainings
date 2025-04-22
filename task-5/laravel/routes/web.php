<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Queue;


Route::get('/', function () {
    return view('welcome');
});

Route::get('/health', function () {
    try {
        DB::connection()->getPdo();
        $dbStatus = 'ok';
    } catch (\Exception $e) {
        $dbStatus = 'error: ' . $e->getMessage();
    }

    try {
        Cache::put('healthcheck', 'ok', 1);
        $cacheStatus = Cache::get('healthcheck') === 'ok' ? 'ok' : 'fail';
    } catch (\Exception $e) {
        $cacheStatus = 'error: ' . $e->getMessage();
    }

    try {
        Storage::put('healthcheck.txt', 'ok');
        $fileStatus = Storage::exists('healthcheck.txt') ? 'ok' : 'fail';
        Storage::delete('healthcheck.txt');
    } catch (\Exception $e) {
        $fileStatus = 'error: ' . $e->getMessage();
    }

    try {
        $queueStatus = Queue::getDefaultDriver() ? 'ok' : 'fail';
    } catch (\Exception $e) {
        $queueStatus = 'error: ' . $e->getMessage();
    }

    return response()->json([
        'status' => ($dbStatus === 'ok' && $cacheStatus === 'ok' && $fileStatus === 'ok') ? 'ok' : 'fail',
        'php' => PHP_VERSION,
        'laravel' => app()->version(),
        'database' => $dbStatus,
        'cache' => $cacheStatus,
        'storage' => $fileStatus,
        'queue' => $queueStatus,
    ]);
});

