import ArgumentParser

@main
struct TrimmerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trimmer",
        abstract: "Fast video trimmer using ffmpeg stream copy (O(1) speed)",
        subcommands: [InfoCommand.self, TrimCommand.self, ExtractCommand.self, CutCommand.self]
    )
}
