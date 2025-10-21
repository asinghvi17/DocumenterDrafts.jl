# Example: Checking Draft Status in Custom Code
#
# This file demonstrates how to check if a page is marked as a draft
# in your custom Documenter extensions or post-processing scripts.

using Documenter

"""
Example function that could be used in a custom writer or post-processor
to check if a page is marked as a draft and adjust rendering accordingly.
"""
function process_page(page::Documenter.Documents.Page)
    # Check if the page is marked as a draft
    is_draft = get(page.globals.meta, :Draft, false)

    if is_draft
        @info "Processing draft page" page.source

        # Example actions for draft pages:
        # 1. Add a "DRAFT" banner/watermark
        # 2. Add <meta name="robots" content="noindex"> to prevent search indexing
        # 3. Skip expensive operations (diagram rendering, code execution, etc.)
        # 4. Use faster/simpler rendering
        # 5. Add visual indicators in the UI

        return process_as_draft(page)
    else
        @info "Processing full page" page.source

        # Full rendering with all features
        return process_fully(page)
    end
end

function process_as_draft(page)
    # Simplified processing for draft pages
    println("  ⚠️  DRAFT MODE: Skipping expensive rendering")
    # ... your draft rendering logic ...
end

function process_fully(page)
    # Full processing for non-draft pages
    println("  ✓  FULL MODE: Complete rendering with all features")
    # ... your full rendering logic ...
end


"""
Example: Custom HTML writer that adds a draft banner
"""
function add_draft_banner_if_needed(html_content::String, page::Documenter.Documents.Page)
    is_draft = get(page.globals.meta, :Draft, false)

    if is_draft
        # Prepend a draft banner to the HTML content
        draft_banner = """
        <div style="background-color: #fff3cd; border: 2px solid #ffc107; padding: 1rem; margin: 1rem 0;">
            <strong>⚠️ DRAFT</strong>: This page is a preview and may not be complete.
            Only modified pages are fully rendered in PR builds.
        </div>
        """
        return draft_banner * html_content
    end

    return html_content
end


"""
Example: Check all pages in a document for draft status
"""
function report_draft_status(doc::Documenter.Documents.Document)
    println("Draft Status Report:")
    println("=" ^ 50)

    draft_count = 0
    full_count = 0

    for (filename, page) in doc.blueprint.pages
        is_draft = get(page.globals.meta, :Draft, false)

        status = is_draft ? "DRAFT" : "FULL"
        marker = is_draft ? "⚠️" : "✓"

        println("  $marker  $status: $filename")

        if is_draft
            draft_count += 1
        else
            full_count += 1
        end
    end

    println("=" ^ 50)
    println("Summary: $full_count full, $draft_count draft")
    println()

    # Calculate potential savings
    if draft_count > 0
        percentage = round(Int, 100 * draft_count / (draft_count + full_count))
        println("Potential build optimization: ~$percentage% of pages marked as drafts")
    end
end


# Example: How to use this in a custom Documenter pipeline step
"""
    DraftAwareProcessing <: Documenter.Builder.DocumentPipeline

Custom pipeline step that processes pages differently based on draft status.
Runs after DraftMarking (priority > 0.9).
"""
# abstract type DraftAwareProcessing <: Documenter.Builder.DocumentPipeline end
#
# Documenter.Selectors.order(::Type{DraftAwareProcessing}) = 2.5  # After ExpandTemplates
#
# function Documenter.Selectors.runner(::Type{DraftAwareProcessing}, doc::Documenter.Documents.Document)
#     for (filename, page) in doc.blueprint.pages
#         process_page(page)
#     end
#
#     # Generate a report
#     report_draft_status(doc)
# end
