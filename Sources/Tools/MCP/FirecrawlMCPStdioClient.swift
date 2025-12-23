import Foundation
import SwiftyPrompts

#if os(macOS) || os(Linux)

/// A client for interacting with the Firecrawl MCP server via standard input/output
public class FirecrawlMCPStdioClient {
    /// The underlying MCP stdio client
    private let mcpClient: MCPStdioClient
    
    /// Initialize a new Firecrawl MCP stdio client
    /// - Parameters:
    ///   - executableURL: URL of the MCP server executable (e.g., npx)
    ///   - arguments: Arguments to pass to the executable (e.g., ["-y", "firecrawl-mcp"])
    ///   - environment: Environment variables to set for the process (e.g., ["FIRECRAWL_API_KEY": "your-api-key"])
    public init(executableURL: URL, arguments: [String] = [], environment: [String: String]? = nil) throws {
        self.mcpClient = try MCPStdioClient(executableURL: executableURL, arguments: arguments, environment: environment)
    }
    
    // MARK: - Scrape Tool
    
    /// Scrape content from a single URL with advanced options
    /// - Parameters:
    ///   - url: The URL to scrape
    ///   - formats: Content formats to extract (default: ["markdown"])
    ///   - onlyMainContent: Extract only the main content
    ///   - waitFor: Time in milliseconds to wait for dynamic content to load
    ///   - timeout: Maximum time in milliseconds to wait for the page to load
    ///   - mobile: Use mobile viewport
    ///   - includeTags: HTML tags to specifically include in extraction
    ///   - excludeTags: HTML tags to exclude from extraction
    ///   - skipTlsVerification: Skip TLS certificate verification
    /// - Returns: Response from the MCP server
    public func scrape(url: String, formats: [String] = ["markdown"], 
                       onlyMainContent: Bool = true, waitFor: Int? = nil,
                       timeout: Int? = nil, mobile: Bool? = nil,
                       includeTags: [String]? = nil, excludeTags: [String]? = nil,
                       skipTlsVerification: Bool? = nil) async throws -> MCPResponse {
        var arguments: [String: Any] = [
            "url": url,
            "formats": formats,
            "onlyMainContent": onlyMainContent
        ]
        
        // Add optional parameters
        if let waitFor = waitFor {
            arguments["waitFor"] = waitFor
        }
        if let timeout = timeout {
            arguments["timeout"] = timeout
        }
        if let mobile = mobile {
            arguments["mobile"] = mobile
        }
        if let includeTags = includeTags {
            arguments["includeTags"] = includeTags
        }
        if let excludeTags = excludeTags {
            arguments["excludeTags"] = excludeTags
        }
        if let skipTlsVerification = skipTlsVerification {
            arguments["skipTlsVerification"] = skipTlsVerification
        }
        
        return try await mcpClient.callTool(name: "firecrawl_scrape", arguments: arguments)
    }
    
    // MARK: - Batch Scrape Tool
    
    /// Scrape multiple URLs efficiently with built-in rate limiting and parallel processing
    /// - Parameters:
    ///   - urls: List of URLs to scrape
    ///   - options: Options for scraping
    /// - Returns: Response from the MCP server
    public func batchScrape(urls: [String], options: [String: Any]? = nil) async throws -> MCPResponse {
        var arguments: [String: Any] = [
            "urls": urls
        ]
        
        if let options = options {
            arguments["options"] = options
        }
        
        return try await mcpClient.callTool(name: "firecrawl_batch_scrape", arguments: arguments)
    }
    
    // MARK: - Check Batch Status Tool
    
    /// Check the status of a batch operation
    /// - Parameter id: Batch operation ID
    /// - Returns: Response from the MCP server
    public func checkBatchStatus(id: String) async throws -> MCPResponse {
        let arguments: [String: Any] = [
            "id": id
        ]
        
        return try await mcpClient.callTool(name: "firecrawl_check_batch_status", arguments: arguments)
    }
    
    // MARK: - Search Tool
    
    /// Search the web and optionally extract content from search results
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results to return
    ///   - lang: Language code for search results
    ///   - country: Country code for search results
    ///   - scrapeOptions: Options for scraping search results
    /// - Returns: Response from the MCP server
    public func search(query: String, limit: Int = 5, lang: String = "en",
                      country: String = "us", scrapeOptions: [String: Any]? = nil) async throws -> MCPResponse {
        var arguments: [String: Any] = [
            "query": query,
            "limit": limit,
            "lang": lang,
            "country": country
        ]
        
        if let scrapeOptions = scrapeOptions {
            arguments["scrapeOptions"] = scrapeOptions
        }
        
        return try await mcpClient.callTool(name: "firecrawl_search", arguments: arguments)
    }
    
    // MARK: - Crawl Tool
    
    /// Start an asynchronous crawl with advanced options
    /// - Parameters:
    ///   - url: Starting URL for the crawl
    ///   - maxDepth: Maximum link depth to crawl
    ///   - limit: Maximum number of pages to crawl
    ///   - allowExternalLinks: Allow crawling links to external domains
    ///   - allowBackwardLinks: Allow crawling links that point to parent directories
    ///   - deduplicateSimilarURLs: Remove similar URLs during crawl
    ///   - ignoreQueryParameters: Ignore query parameters when comparing URLs
    ///   - ignoreSitemap: Skip sitemap.xml discovery
    ///   - includePaths: Only crawl these URL paths
    ///   - excludePaths: URL paths to exclude from crawling
    ///   - scrapeOptions: Options for scraping each page
    /// - Returns: Response from the MCP server
    public func crawl(url: String, maxDepth: Int? = nil, limit: Int? = nil,
                     allowExternalLinks: Bool? = nil, allowBackwardLinks: Bool? = nil,
                     deduplicateSimilarURLs: Bool? = nil, ignoreQueryParameters: Bool? = nil,
                     ignoreSitemap: Bool? = nil, includePaths: [String]? = nil,
                     excludePaths: [String]? = nil, scrapeOptions: [String: Any]? = nil) async throws -> MCPResponse {
        var arguments: [String: Any] = [
            "url": url
        ]
        
        // Add optional parameters
        if let maxDepth = maxDepth {
            arguments["maxDepth"] = maxDepth
        }
        if let limit = limit {
            arguments["limit"] = limit
        }
        if let allowExternalLinks = allowExternalLinks {
            arguments["allowExternalLinks"] = allowExternalLinks
        }
        if let allowBackwardLinks = allowBackwardLinks {
            arguments["allowBackwardLinks"] = allowBackwardLinks
        }
        if let deduplicateSimilarURLs = deduplicateSimilarURLs {
            arguments["deduplicateSimilarURLs"] = deduplicateSimilarURLs
        }
        if let ignoreQueryParameters = ignoreQueryParameters {
            arguments["ignoreQueryParameters"] = ignoreQueryParameters
        }
        if let ignoreSitemap = ignoreSitemap {
            arguments["ignoreSitemap"] = ignoreSitemap
        }
        if let includePaths = includePaths {
            arguments["includePaths"] = includePaths
        }
        if let excludePaths = excludePaths {
            arguments["excludePaths"] = excludePaths
        }
        if let scrapeOptions = scrapeOptions {
            arguments["scrapeOptions"] = scrapeOptions
        }
        
        return try await mcpClient.callTool(name: "firecrawl_crawl", arguments: arguments)
    }
    
    // MARK: - Check Crawl Status Tool
    
    /// Check the status of a crawl operation
    /// - Parameter id: Crawl operation ID
    /// - Returns: Response from the MCP server
    public func checkCrawlStatus(id: String) async throws -> MCPResponse {
        let arguments: [String: Any] = [
            "id": id
        ]
        
        return try await mcpClient.callTool(name: "firecrawl_check_crawl_status", arguments: arguments)
    }
    
    // MARK: - Extract Tool
    
    /// Extract structured information from web pages using LLM capabilities
    /// - Parameters:
    ///   - urls: List of URLs to extract information from
    ///   - prompt: Custom prompt for the LLM extraction
    ///   - systemPrompt: System prompt to guide the LLM
    ///   - schema: JSON schema for structured data extraction
    ///   - allowExternalLinks: Allow extraction from external links
    ///   - enableWebSearch: Enable web search for additional context
    ///   - includeSubdomains: Include subdomains in extraction
    /// - Returns: Response from the MCP server
    public func extract(urls: [String], prompt: String, systemPrompt: String? = nil,
                       schema: [String: Any], allowExternalLinks: Bool? = nil,
                       enableWebSearch: Bool? = nil, includeSubdomains: Bool? = nil) async throws -> MCPResponse {
        var arguments: [String: Any] = [
            "urls": urls,
            "prompt": prompt,
            "schema": schema
        ]
        
        // Add optional parameters
        if let systemPrompt = systemPrompt {
            arguments["systemPrompt"] = systemPrompt
        }
        if let allowExternalLinks = allowExternalLinks {
            arguments["allowExternalLinks"] = allowExternalLinks
        }
        if let enableWebSearch = enableWebSearch {
            arguments["enableWebSearch"] = enableWebSearch
        }
        if let includeSubdomains = includeSubdomains {
            arguments["includeSubdomains"] = includeSubdomains
        }
        
        return try await mcpClient.callTool(name: "firecrawl_extract", arguments: arguments)
    }
    
    // MARK: - Deep Research Tool
    
    /// Conduct deep research on a query using web crawling, search, and AI analysis
    /// - Parameters:
    ///   - query: The query to research
    ///   - maxDepth: Maximum depth of research iterations
    ///   - maxUrls: Maximum number of URLs to analyze
    ///   - timeLimit: Time limit in seconds
    /// - Returns: Response from the MCP server
    public func deepResearch(query: String, maxDepth: Int? = nil,
                            maxUrls: Int? = nil, timeLimit: Int? = nil) async throws -> MCPResponse {
        var arguments: [String: Any] = [
            "query": query
        ]
        
        // Add optional parameters
        if let maxDepth = maxDepth {
            arguments["maxDepth"] = maxDepth
        }
        if let maxUrls = maxUrls {
            arguments["maxUrls"] = maxUrls
        }
        if let timeLimit = timeLimit {
            arguments["timeLimit"] = timeLimit
        }
        
        return try await mcpClient.callTool(name: "firecrawl_deep_research", arguments: arguments)
    }
    
    // MARK: - Map Tool
    
    /// Discover URLs from a starting point. Can use both sitemap.xml and HTML link discovery
    /// - Parameters:
    ///   - url: Starting URL for URL discovery
    ///   - ignoreSitemap: Skip sitemap.xml discovery and only use HTML links
    ///   - includeSubdomains: Include URLs from subdomains in results
    ///   - limit: Maximum number of URLs to return
    ///   - search: Optional search term to filter URLs
    ///   - sitemapOnly: Only use sitemap.xml for discovery, ignore HTML links
    /// - Returns: Response from the MCP server
    public func map(url: String, ignoreSitemap: Bool? = nil,
                   includeSubdomains: Bool? = nil, limit: Int? = nil,
                   search: String? = nil, sitemapOnly: Bool? = nil) async throws -> MCPResponse {
        var arguments: [String: Any] = [
            "url": url
        ]
        
        // Add optional parameters
        if let ignoreSitemap = ignoreSitemap {
            arguments["ignoreSitemap"] = ignoreSitemap
        }
        if let includeSubdomains = includeSubdomains {
            arguments["includeSubdomains"] = includeSubdomains
        }
        if let limit = limit {
            arguments["limit"] = limit
        }
        if let search = search {
            arguments["search"] = search
        }
        if let sitemapOnly = sitemapOnly {
            arguments["sitemapOnly"] = sitemapOnly
        }
        
        return try await mcpClient.callTool(name: "firecrawl_map", arguments: arguments)
    }
    
    /// Terminate the MCP server process
    public func terminate() {
        mcpClient.terminate()
    }
    
    deinit {
        terminate()
    }
}
#endif
