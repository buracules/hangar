import Foundation
import Testing

@testable import Hangar

struct MachineStatusTests {
  private func container(state: String, status: String) -> Container {
    Container(
      id: "abc",
      names: ["/x"],
      image: "postgres:17",
      state: state,
      status: status,
      labels: nil,
      ports: nil
    )
  }

  @Test(arguments: [
    ("running", "Up 2 hours", MachineStatus.Kind.running, "Running"),
    ("running", "Up 2 hours (healthy)", .running, "Running"),
    ("running", "Up 2 hours (unhealthy)", .unhealthy, "Unhealthy"),
    ("running", "Up 3 seconds (health: starting)", .busy, "Starting"),
    ("paused", "Up 2 hours (Paused)", .paused, "Paused"),
    ("restarting", "Restarting (1) 5 seconds ago", .busy, "Restarting"),
    ("exited", "Exited (0) 3 minutes ago", .stopped, "Stopped"),
    ("exited", "Exited (137) 2 days ago", .error, "Exited"),
    ("created", "Created", .stopped, "Created"),
    ("dead", "Dead", .error, "Dead"),
  ])
  func aContainersStatusFollowsStateHealthAndExitCode(
    state: String,
    status: String,
    kind: MachineStatus.Kind,
    word: String
  ) {
    let result = container(state: state, status: status).machineStatus

    #expect(result == MachineStatus(kind: kind, word: word))
  }

  @Test func healthAndExitCodeAreReadFromTheStatusText() {
    #expect(container(state: "running", status: "Up 2 hours (healthy)").health == .healthy)
    #expect(container(state: "running", status: "Up 2 hours").health == nil)
    #expect(container(state: "exited", status: "Exited (137) 2 days ago").exitCode == 137)
    #expect(container(state: "running", status: "Up 2 hours").exitCode == nil)
  }

  @Test func theStatusDetailDropsWhatTheStatusAlreadySays() {
    let up = container(state: "running", status: "Up 2 hours (healthy)")
    let down = container(state: "exited", status: "Exited (0) 3 minutes ago")

    #expect(up.statusDetail == "Up 2 hours")
    #expect(down.statusDetail == "3 minutes ago")
  }

  @Test(arguments: [
    ("started", MachineStatus.Kind.running, "Running"),
    ("paused", .paused, "Paused"),
    ("starting", .busy, "Starting"),
    ("stopping", .busy, "Stopping"),
    ("stopped", .stopped, "Stopped"),
  ])
  func aVMsStatusFollowsUtmctl(status: String, kind: MachineStatus.Kind, word: String) {
    let vm = VirtualMachine(id: "1", name: "berqNET", status: status)

    #expect(MachineStatus(vm) == MachineStatus(kind: kind, word: word))
  }
}
