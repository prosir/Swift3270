import Foundation
import Subprocess
import Swift3270WindowsCore
import SystemPackage

struct WS3270Configuration: Sendable {
    var executable: String
    var model: Int
    var oversize: String?
}

enum WS3270Event: Sendable {
    case response(command: String?, value: WS3270Response)
    case stopped(String?)
}

private actor CommandTracker {
    private var commands: [String] = []

    func sent(_ command: String) {
        commands.append(command)
    }

    func completed() -> String? {
        commands.isEmpty ? nil : commands.removeFirst()
    }
}

actor WS3270Backend {
    private var commandContinuation: AsyncStream<String>.Continuation?
    private var processTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    var isRunning: Bool { processTask != nil }

    func start(
        configuration: WS3270Configuration,
        onEvent: @escaping @Sendable (WS3270Event) -> Void
    ) {
        guard processTask == nil else { return }

        var continuation: AsyncStream<String>.Continuation?
        let commands = AsyncStream<String> { continuation = $0 }
        commandContinuation = continuation

        processTask = Task { [weak self] in
            let tracker = CommandTracker()
            do {
                var arguments = [
                    "-utf8",
                    "-model", "3279-\(configuration.model)",
                    "-set", "blankFill",
                    "-clear", "aidWait"
                ]
                if let oversize = configuration.oversize, !oversize.isEmpty {
                    arguments += ["-oversize", oversize]
                }

                let executable: Executable
                if configuration.executable.contains("\\") || configuration.executable.contains("/") {
                    executable = .path(FilePath(configuration.executable))
                } else {
                    executable = .name(configuration.executable)
                }

                _ = try await run(
                    executable,
                    arguments: Arguments(arguments),
                    error: .discarded
                ) { _, standardInputWriter, standardOutput in
                    let writerTask = Task {
                        for await command in commands {
                            try Task.checkCancellation()
                            await tracker.sent(command)
                            _ = try await standardInputWriter.write(Array((command + "\n").utf8))
                        }
                        try await standardInputWriter.finish()
                    }

                    var parser = WS3270ResponseParser()
                    do {
                        for try await line in standardOutput.lines() {
                            if let response = parser.consume(line) {
                                let command = await tracker.completed()
                                onEvent(.response(command: command, value: response))
                            }
                        }
                    } catch {
                        writerTask.cancel()
                        _ = await writerTask.result
                        throw error
                    }
                    writerTask.cancel()
                    _ = await writerTask.result
                }
                onEvent(.stopped(nil))
            } catch is CancellationError {
                onEvent(.stopped(nil))
            } catch {
                onEvent(.stopped(error.localizedDescription))
            }
            await self?.processEnded()
        }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { break }
                await self?.send("Ascii")
            }
        }
    }

    func send(_ command: String) {
        commandContinuation?.yield(command)
    }

    func sendAndRefresh(_ command: String) {
        commandContinuation?.yield(command)
        commandContinuation?.yield("Ascii")
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        commandContinuation?.yield("Quit")
        commandContinuation?.finish()
        commandContinuation = nil
    }

    private func processEnded() {
        pollTask?.cancel()
        pollTask = nil
        commandContinuation?.finish()
        commandContinuation = nil
        processTask = nil
    }
}
