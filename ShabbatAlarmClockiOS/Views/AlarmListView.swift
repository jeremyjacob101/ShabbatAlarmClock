//
//  AlarmListView.swift
//  ShabbatAlarmClockiOS
//
//  Created by Jeremy Jacob on 22/02/2026.
//


import SwiftUI

struct AlarmListView: View {
    @StateObject private var viewModel = AlarmListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.alarms.isEmpty {
                    ContentUnavailableView(
                        "No Alarms Yet",
                        systemImage: "alarm",
                        description: Text("Tap + to create your first alarm.")
                    )
                } else {
                    List {
                        ForEach(viewModel.alarms) { alarm in
                            AlarmRowView(
                                alarm: alarm,
                                onToggle: { isOn in
                                    viewModel.toggleAlarm(id: alarm.id, isEnabled: isOn)
                                }
                            )
                        }
                        .onDelete(perform: viewModel.deleteAlarms)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.requestNotificationPermissionIfNeeded()
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                    .accessibilityLabel("Request notification permission")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddAlarm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(isPresented: $viewModel.showAddAlarm) {
                AddAlarmView { time, label in
                    viewModel.addAlarm(time: time, label: label)
                }
            }
            .alert("Notice", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}

#Preview {
    AlarmListView()
}
