import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SidebarSection } from "./SidebarSection.tsx";

describe("SidebarSection", () => {
  it("renders label and child when expanded", () => {
    render(
      <SidebarSection label="工具" expanded={true} onToggle={() => {}}>
        <div>child-content</div>
      </SidebarSection>
    );
    expect(screen.getByText("工具")).toBeInTheDocument();
    expect(screen.getByText("child-content")).toBeInTheDocument();
  });

  it("hides children when collapsed", () => {
    render(
      <SidebarSection label="工具" expanded={false} onToggle={() => {}}>
        <div>child-content</div>
      </SidebarSection>
    );
    expect(screen.queryByText("child-content")).not.toBeInTheDocument();
  });

  it("calls onToggle on header click", () => {
    const onToggle = vi.fn();
    render(
      <SidebarSection label="工具" expanded={true} onToggle={onToggle}>
        <div />
      </SidebarSection>
    );
    fireEvent.click(screen.getByRole("button", { name: /工具/i }));
    expect(onToggle).toHaveBeenCalledTimes(1);
  });

  it("renders short-line indicator when collapsedSidebar", () => {
    render(
      <SidebarSection label="工具" expanded={true} onToggle={() => {}} collapsedSidebar={true}>
        <div>child</div>
      </SidebarSection>
    );
    // label text should not be rendered when sidebar is collapsed
    expect(screen.queryByText("工具")).not.toBeInTheDocument();
    // header is still clickable
    expect(screen.getByRole("button")).toBeInTheDocument();
  });
});
