<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
                xmlns:date="http://exslt.org/dates-and-times"
                xmlns:parse="http://cdlib.org/xtf/parse"
                xmlns:xtf="http://cdlib.org/xtf"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:cudl="http://cudl.lib.cam.ac.uk/xtf/"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                extension-element-prefixes="date"
                exclude-result-prefixes="#all">


    <!--All msdesc TEI gets sent here from docSelector.xsl. Transforms TEI into local xml format and passes it on to docFormatter for conversion into json
      Indexing for search and facetting are handled by a separate xtf instance, CUDL-XTF, maintained by the development team

      QUERY - do we need xtf:subDocument attributes here now that indexing is done in CUDL-XTF?
      QUERY - how are we handling top-level msParts? msParts are currently only catered for in the limited way they are used in the Sanskrit material, e.g. MS-ADD-01662


   -->

    <!-- Variables expected by templates-->
    <xsl:variable name="fileID" select="substring-before(tokenize(document-uri(/), '/')[last()], '.xml')"/>

    <!-- ====================================================================== -->
    <!-- Languages and writing direction                                       -->
    <!-- ====================================================================== -->

    <!--default is left to right, so only list those which are not-->

    <xsl:variable name="languages-direction">

        <languages>
            <language>
                <code>heb</code><direction>R</direction>
            </language>
            <language>
                <code>ara</code><direction>R</direction>
            </language>
            <language>
                <code>arc</code><direction>R</direction>
            </language>
            <language>
                <code>per</code><direction>R</direction>
            </language>
        </languages>

    </xsl:variable>

    <!-- Common functions -->
    <!-- TODO: import these from one place -->

    <!-- Lookup collections of which this item is a member (from SQL database) -->
    <!-- FIXME: This is very chicken and egg: item metadata shouldn't define the
        collections it's included in, collections decide which items they
        include.
   -->
    <xsl:function name="cudl:get-memberships">
        <xsl:param name="itemid"/>


        <!-- FIXME: Temporarilly returning nothing until we can refactor this out. -->
        <!-- <xsl:for-each select="document(concat($servicesURI, 'v1/rdb/membership/collections/', $itemid))/collections/CollectionJSON">
         <xsl:copy-of select="."/>
      </xsl:for-each> -->
    </xsl:function>

    <!-- Provide page for reproduction requests, based on repository. Temporary hack: this really neeeds to come from data -->
    <xsl:function name="cudl:get-imageReproPageURL">
        <xsl:param name="repository"/>
        <xsl:param name="shelflocator"/>

        <xsl:choose>
            <xsl:when test="$repository='National Maritime Museum'">
                <xsl:text>http://images.rmg.co.uk/en/page/show_home_page.html</xsl:text>
            </xsl:when>
            <xsl:when test="$repository='Cambridge University Collection of Aerial Photography'">
                <xsl:text>https://www.cambridgeairphotos.com/</xsl:text>
            </xsl:when>


            <xsl:when test="$repository='Cavendish Laboratory'">

                <xsl:variable name="urltext" select="concat('https://www.phy.cam.ac.uk/about/image-licensing-form?id=',$shelflocator)"></xsl:variable>
                <xsl:value-of select="$urltext"></xsl:value-of>
                <!--<xsl:text>https://www.phy.cam.ac.uk/about/image-licensing-form</xsl:text>-->
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>https://imagingservices.lib.cam.ac.uk/</xsl:text>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:function>

    <!--Gets text direction from language-->
    <xsl:function name="cudl:get-language-direction">
        <xsl:param name="languageCode" />

        <xsl:choose>
            <xsl:when test="normalize-space($languages-direction/languages/language[code=$languageCode]/direction)">
                <xsl:value-of select="normalize-space($languages-direction/languages/language[code=$languageCode]/direction)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>L</xsl:text>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:function>

    <!--Capitalises first letter of text-->
    <xsl:function name="cudl:first-upper-case">
        <xsl:param name="text" />

        <xsl:value-of select="concat(upper-case(substring($text,1,1)),substring($text, 2))" />
    </xsl:function>

    <!-- ====================================================================== -->
    <!-- Import Common Templates and Functions                                  -->
    <!-- ====================================================================== -->

    <!--just some common functions here-->
    <!-- <xsl:import href="../common/preFilterCommon.xsl"/> -->

    <!-- ====================================================================== -->
    <!-- Output parameters                                                      -->
    <!-- ====================================================================== -->

    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    <xsl:strip-space elements="*"/>

    <!-- ====================================================================== -->
    <!-- Metadata Indexing                                                      -->
    <!-- ====================================================================== -->

    <xsl:template match="/">
        <item>
            <xsl:call-template name="get-meta"/>
        </item>
    </xsl:template>

    <xsl:template name="get-meta">
        <!--descriptive information about the item-->
        <descriptiveMetadata>

            <xsl:call-template name="make-dmd-parts"/>

        </descriptiveMetadata>

        <!--top level fields concerning the document as a whole-->
        <!--how many pages does it have-->
        <xsl:call-template name="get-numberOfPages"/>
        <!--is it embeddable-->
        <xsl:call-template name="get-embeddable"/>

        <!--flags to govern whether transcription/translation exist - used to create tabs-->
        <xsl:call-template name="get-transcription-flags" />

        <!--where is the source metadata available-->
        <xsl:call-template name="get-sourceData"/>

        <!--is this a complete representation of the item-->
        <!--QUERY - deprecate?-->
        <xsl:if test=".//*:note[@type='completeness']">
            <xsl:apply-templates select=".//*:note[@type='completeness']"/>
        </xsl:if>

        <!--structural information about the item-->
        <xsl:call-template name="make-pages" />
        <xsl:call-template name="make-logical-structure" />

        <!--a special case where items in a list with a locus are indexed against that locus-->
        <!--QUERY - can we index straight from the content?-->
        <xsl:if test="//*:list/*:item[*:locus]">
            <xsl:call-template name="make-list-item-pages" />
        </xsl:if>

        <xsl:call-template name="get-text-direction"/>
    </xsl:template>

    <!--*******************Descriptive metadata************************************************************************************-->

    <!--This lays out descriptive metadata parts in the right hierarchy-->

    <!--Descriptive metadata is organised into 'parts' - these are not nesting - hierarchy is organised by ids (like METS)-->

    <!--each part has a unique xtf:subDocument attribute to facilitate search indexing against specific parts-->
    <!--QUERY - do we still need to do this?-->

    <xsl:template name="make-dmd-parts">

        <!--if there are no msParts-->
        <!--QUERY - what do we do if there are top-level msParts?-->
        <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:msItem">
            <xsl:choose>
                <!-- if there is just one top-level msItem, merge into the document level -->
                <xsl:when test="count(//*:sourceDesc/*:msDesc/*:msContents/*:msItem) = 1">



                    <part>

                        <xsl:attribute name="xtf:subDocument" select="'ITEM-1'"/>

                        <xsl:call-template name="get-doc-abstract"/>

                        <xsl:call-template name="get-doc-and-item-names"/>

                        <xsl:call-template name="get-doc-subjects"/>
                        <xsl:call-template name="get-doc-events"/>

                        <xsl:call-template name="get-doc-physloc"/>
                        <xsl:call-template name="get-doc-alt-ids"/>

                        <xsl:call-template name="get-doc-thumbnail"/>

                        <xsl:call-template name="get-doc-image-rights"/>
                        <xsl:call-template name="get-doc-metadata-rights"/>
                        <xsl:call-template name="get-doc-authority"/>

                        <xsl:call-template name="get-doc-funding"/>

                        <xsl:call-template name="get-doc-physdesc"/>
                        <xsl:call-template name="get-doc-history"/>



                        <xsl:call-template name="get-doc-and-item-biblio"/>

                        <xsl:call-template name="get-doc-metadata"/>

                        <xsl:call-template name="get-CollectionJSON-memberships"/>



                        <!--not sure why this is called with a for-each - the above means that there will only ever be one msItem here-->
                        <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]">

                            <xsl:call-template name="get-item-dmdID"/>


                            <xsl:call-template name="get-item-title">
                                <xsl:with-param name="display" select="'false'"/>
                            </xsl:call-template>
                            <xsl:call-template name="get-item-alt-titles"/>
                            <xsl:call-template name="get-item-desc-titles"/>
                            <xsl:call-template name="get-item-uniform-title"/>
                            <!--
                     <xsl:call-template name="get-item-names"/>
                     -->
                            <xsl:call-template name="get-item-languages"/>

                            <xsl:call-template name="get-item-excerpts"/>
                            <xsl:call-template name="get-item-notes"/>
                            <xsl:call-template name="get-item-filiation"/>

                        </xsl:for-each>

                    </part>

                    <!-- Now process any sub-items -->
                    <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]">
                        <xsl:apply-templates select="*:msContents/*:msItem|*:msItem"/>
                    </xsl:for-each>


                    <xsl:apply-templates select="//*:msPart/*:msContents/*:msItem"/>



                </xsl:when>
                <xsl:otherwise>

                    <!-- Sequence of top-level msItems, so need to introduce additional top-level to represent item as a whole-->

                    <part>
                        <xsl:attribute name="xtf:subDocument" select="'DOCUMENT'"/>

                        <xsl:call-template name="get-doc-dmdID"/>
                        <xsl:call-template name="get-doc-title"/>
                        <xsl:call-template name="get-doc-alt-titles"/>
                        <xsl:call-template name="get-doc-desc-titles"/>
                        <xsl:call-template name="get-doc-uniform-title"/>
                        <xsl:call-template name="get-doc-abstract"/>

                        <xsl:call-template name="get-doc-languages"/>
                        <xsl:call-template name="get-doc-notes"/>

                        <xsl:call-template name="get-doc-names"/>

                        <xsl:call-template name="get-doc-subjects"/>
                        <xsl:call-template name="get-doc-events"/>

                        <xsl:call-template name="get-doc-physloc"/>
                        <xsl:call-template name="get-doc-alt-ids"/>

                        <xsl:call-template name="get-doc-thumbnail"/>

                        <xsl:call-template name="get-doc-image-rights"/>
                        <xsl:call-template name="get-doc-metadata-rights"/>
                        <xsl:call-template name="get-doc-authority"/>

                        <xsl:call-template name="get-doc-funding"/>

                        <xsl:call-template name="get-doc-physdesc"/>
                        <xsl:call-template name="get-doc-history"/>

                        <xsl:call-template name="get-doc-biblio"/>

                        <xsl:call-template name="get-doc-metadata"/>

                        <xsl:call-template name="get-CollectionJSON-memberships"/>

                    </part>

                    <!-- Now process top-level msItems -->
                    <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:msContents/*:msItem"/>

                </xsl:otherwise>
            </xsl:choose>


        </xsl:if>

    </xsl:template>

    <!--each msItem is also a part-->
    <xsl:template match="*:msItem">

        <part>

            <!--incrementing number to give a unique id-->
            <xsl:variable name="n-tree">
                <xsl:value-of
                    select="sum((count(ancestor-or-self::*[local-name()='msItem' or local-name()='msPart']), count(preceding::*[local-name()='msItem' or local-name()='msPart'])))"
                />
            </xsl:variable>

            <xsl:attribute name="xtf:subDocument" select="concat('ITEM-', normalize-space($n-tree))"/>


            <xsl:call-template name="get-item-dmdID"/>

            <xsl:call-template name="get-item-title">
                <xsl:with-param name="display" select="'true'"/>
            </xsl:call-template>

            <xsl:call-template name="get-item-alt-titles"/>
            <xsl:call-template name="get-item-desc-titles"/>
            <xsl:call-template name="get-item-uniform-title"/>
            <xsl:call-template name="get-item-names"/>
            <xsl:call-template name="get-item-languages"/>

            <xsl:call-template name="get-item-excerpts"/>
            <xsl:call-template name="get-item-notes"/>

            <xsl:call-template name="get-item-filiation"/>

            <xsl:call-template name="get-item-biblio"/>

            <xsl:call-template name="get-CollectionJSON-memberships"/>

        </part>

        <!-- Any child items of this item -->
        <xsl:apply-templates select="*:msContents/*:msItem|*:msItem"/>

    </xsl:template>



    <!--*************************and these are the templates which fill in descriptive metadata fields-->

    <!--DMDIDs-->

    <!--for the whole document-->
    <xsl:template name="get-doc-dmdID">

        <ID>
            <xsl:value-of select="'DOCUMENT'"/>
        </ID>

        <fileID>
            <xsl:value-of select="$fileID"/>
        </fileID>

        <startPage>1</startPage>
        <!--documents always start on page 1!-->
        <startPageLabel>

            <xsl:choose>
                <xsl:when test="normalize-space(//*:facsimile/*:surface[1]/@n)">
                    <xsl:value-of select="//*:facsimile/*:surface[1]/@n"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>1</xsl:text>
                </xsl:otherwise>
            </xsl:choose>

        </startPageLabel>

    </xsl:template>

    <!--for individual items-->
    <xsl:template name="get-item-dmdID">

        <!--incrementing number to give a unique id-->
        <xsl:variable name="n-tree">
            <xsl:value-of
                select="sum((count(ancestor-or-self::*[local-name()='msItem' or local-name()='msPart']), count(preceding::*[local-name()='msItem' or local-name()='msPart'])))"
            />
        </xsl:variable>

        <ID>
            <xsl:value-of select="concat('ITEM-', normalize-space($n-tree))"/>
        </ID>

        <fileID>
            <xsl:value-of select="$fileID"/>
        </fileID>

        <xsl:variable name="startPageLabel">
            <!--should always be a locus attached to an msItem - but defaults to first page if none present-->
            <xsl:choose>
                <xsl:when test="*:locus/@from">
                    <xsl:value-of select="normalize-space(*:locus/@from)" />

                </xsl:when>
                <xsl:when test="//*:facsimile/*:surface[1]/@n">
                    <xsl:value-of select="normalize-space(//*:facsimile/*:surface[1]/@n)" />

                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>cover</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <startPageLabel>
            <xsl:value-of select="$startPageLabel"/>

        </startPageLabel>

        <xsl:variable name="startPage">

            <xsl:choose>
                <xsl:when test="//*:facsimile/*:surface[@n=$startPageLabel]">
                    <xsl:for-each select="//*:facsimile/*:surface" >
                        <xsl:if test="@n = $startPageLabel">
                            <xsl:value-of select="position()" />
                        </xsl:if>
                    </xsl:for-each>

                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>cover</xsl:text>
                </xsl:otherwise>
            </xsl:choose>

        </xsl:variable>

        <startPage>
            <xsl:value-of select="$startPage"/>
        </startPage>

    </xsl:template>


    <!--TITLES-->

    <!--main titles-->
    <!--whole document titles where there are multiple msItems are found in the summary - if not present, defaults to classmark-->


    <xsl:template name="get-doc-title">
        <title>
            <xsl:variable name="title">

                <xsl:choose>
                    <xsl:when
                        test="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:title[@type='general']">
                        <xsl:for-each-group
                            select="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:title[@type='general']"
                            group-by="normalize-space(.)">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text>, </xsl:text>
                            </xsl:if>
                        </xsl:for-each-group>
                    </xsl:when>
                    <xsl:when test="//*:sourceDesc/*:msDesc/*:head">
                        <xsl:value-of select="normalize-space(//*:sourceDesc/*:msDesc/*:head)"/>
                    </xsl:when>
                    <xsl:when test="//*:sourceDesc/*:msDesc/*:msIdentifier/*:msName">
                        <xsl:value-of select="normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:msName)"/>
                    </xsl:when>
                    <xsl:when test="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:title[not(@type)]">
                        <xsl:for-each-group
                            select="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:title[not(@type)]"
                            group-by="normalize-space(.)">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text>, </xsl:text>
                            </xsl:if>
                        </xsl:for-each-group>
                    </xsl:when>
                    <xsl:when test="//*:sourceDesc/*:msDesc/*:msIdentifier/*:idno">
                        <xsl:for-each-group select="//*:sourceDesc/*:msDesc/*:msIdentifier/*:idno"
                                            group-by="normalize-space(.)">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text>, </xsl:text>
                            </xsl:if>
                        </xsl:for-each-group>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Untitled Document</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <xsl:attribute name="display" select="'false'"/>

            <xsl:attribute name="displayForm" select="$title"/>

            <xsl:value-of select="$title"/>

        </title>
    </xsl:template>


    <!--item titles-->
    <xsl:template name="get-item-title">
        <xsl:param name="display" select="'true'"/>

        <title>


            <xsl:variable name="title">
                <xsl:choose>
                    <xsl:when test="normalize-space(*:title[not(@type)][1])">
                        <xsl:value-of select="normalize-space(*:title[not(@type)][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:title[@type='general'][1])">
                        <xsl:value-of select="normalize-space(*:title[@type='general'][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:title[@type='standard'][1])">
                        <xsl:value-of select="normalize-space(*:title[@type='standard'][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:title[@type='supplied'][1])">
                        <xsl:value-of select="normalize-space(*:title[@type='supplied'][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:rubric)">
                        <xsl:variable name="rubric_title">

                            <xsl:apply-templates select="*:rubric" mode="title"/>

                        </xsl:variable>

                        <xsl:value-of select="normalize-space($rubric_title)"/>
                    </xsl:when>

                    <xsl:when test="normalize-space(*:incipit)">
                        <xsl:variable name="incipit_title">

                            <xsl:apply-templates select="*:incipit" mode="title"/>

                        </xsl:variable>

                        <xsl:value-of select="normalize-space($incipit_title)"/>
                    </xsl:when>


                    <xsl:otherwise>
                        <xsl:text>Untitled Item</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <xsl:attribute name="display" select="$display"/>

            <xsl:attribute name="displayForm" select="$title"/>

            <xsl:value-of select="$title"/>

        </title>
    </xsl:template>


    <!--alternative titles-->
    <xsl:template name="get-doc-alt-titles">

        <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:summary/*:title[@type='alt']">

            <alternativeTitles>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each
                    select="//*:sourceDesc/*:msDesc/*:msContents/*:summary/*:title[@type='alt']">

                    <!-- <xsl:if test="not(normalize-space(.) = '')"> -->

                    <xsl:if test="normalize-space(.)">

                        <alternativeTitle>

                            <xsl:attribute name="display" select="'true'"/>

                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                            <xsl:value-of select="normalize-space(.)"/>
                        </alternativeTitle>

                    </xsl:if>

                </xsl:for-each>

            </alternativeTitles>

        </xsl:if>

    </xsl:template>


    <xsl:template name="get-item-alt-titles">

        <xsl:if test="*:title[@type='alt']">

            <alternativeTitles>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="*:title[@type='alt']">

                    <xsl:if test="normalize-space(.)">

                        <alternativeTitle>

                            <xsl:attribute name="display" select="'true'"/>

                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                            <xsl:value-of select="normalize-space(.)"/>
                        </alternativeTitle>

                    </xsl:if>

                </xsl:for-each>
            </alternativeTitles>

        </xsl:if>

    </xsl:template>

    <!--descriptive titles-->
    <xsl:template name="get-doc-desc-titles">

        <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:summary/*:title[@type='desc']">

            <descriptiveTitles>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each
                    select="//*:sourceDesc/*:msDesc/*:msContents/*:summary/*:title[@type='desc']">

                    <!-- <xsl:if test="not(normalize-space(.) = '')"> -->

                    <xsl:if test="normalize-space(.)">

                        <descriptiveTitle>

                            <xsl:attribute name="display" select="'true'"/>

                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                            <xsl:value-of select="normalize-space(.)"/>
                        </descriptiveTitle>

                    </xsl:if>

                </xsl:for-each>

            </descriptiveTitles>

        </xsl:if>

    </xsl:template>

    <xsl:template name="get-item-desc-titles">

        <xsl:if test="*:title[@type='desc']">

            <descriptiveTitles>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="*:title[@type='desc']">

                    <xsl:if test="normalize-space(.)">

                        <descriptiveTitle>

                            <xsl:attribute name="display" select="'true'"/>

                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                            <xsl:value-of select="normalize-space(.)"/>
                        </descriptiveTitle>

                    </xsl:if>

                </xsl:for-each>
            </descriptiveTitles>

        </xsl:if>

    </xsl:template>


    <!--uniform title-->
    <xsl:template name="get-doc-uniform-title">

        <xsl:variable name="uniformTitle"
                      select="//*:sourceDesc/*:msDesc/*:msContents/*:summary/*:title[@type='uniform'][1]"/>

        <xsl:if test="normalize-space($uniformTitle)">

            <uniformTitle>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:attribute name="displayForm" select="normalize-space($uniformTitle)"/>

                <xsl:value-of select="normalize-space($uniformTitle)"/>

            </uniformTitle>

        </xsl:if>

    </xsl:template>

    <xsl:template name="get-item-uniform-title">

        <xsl:variable name="uniformTitle" select="*:title[@type='uniform'][1]"/>

        <xsl:if test="normalize-space($uniformTitle)">

            <uniformTitle>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:attribute name="displayForm" select="normalize-space($uniformTitle)"/>

                <xsl:value-of select="normalize-space($uniformTitle)"/>

            </uniformTitle>

        </xsl:if>

    </xsl:template>


    <!--ABSTRACTS-->

    <xsl:template name="get-doc-abstract">

        <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:summary">

            <abstract>

                <xsl:variable name="abstract">
                    <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:msContents/*:summary"
                                         mode="html"/>
                </xsl:variable>

                <xsl:attribute name="display" select="'false'"/>

                <xsl:attribute name="displayForm" select="normalize-space($abstract)"/>

                <!-- <xsl:value-of select="normalize-space($abstract)" /> -->
                <xsl:value-of select="normalize-space(replace($abstract, '&lt;[^&gt;]+&gt;', ''))"/>

            </abstract>

        </xsl:if>

    </xsl:template>

    <xsl:template match="*:summary" mode="html">

        <!--we need to put this in a paragraph if the summary itself contains no paragraphs-->
        <xsl:choose>
            <xsl:when test=".//*:seg[@type='para']">


                <xsl:apply-templates mode="html"/>

            </xsl:when>
            <xsl:otherwise>

                <xsl:text>&lt;p style=&apos;text-align: justify;&apos;&gt;</xsl:text>
                <xsl:apply-templates mode="html"/>
                <xsl:text>&lt;/p&gt;</xsl:text>


            </xsl:otherwise>

        </xsl:choose>


    </xsl:template>

    <!--SUBJECTS-->
    <xsl:template name="get-doc-subjects">

        <xsl:if
            test="//*:profileDesc/*:textClass/*:keywords/*:list/*:item|//*:profileDesc/*:textClass/*:keywords[@scheme='Topic']/*:term">

            <subjects>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="//*:profileDesc/*:textClass/*:keywords/*:list/*:item">

                    <xsl:if test="normalize-space(.)">

                        <subject>

                            <xsl:attribute name="display" select="'true'"/>

                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                            <fullForm>
                                <xsl:value-of select="normalize-space(.)"/>
                            </fullForm>

                            <xsl:if test="*:ref/@target">
                                <authority>
                                    <xsl:value-of
                                        select="normalize-space(id(substring-after(../../@scheme, '#'))/*:bibl/*:ref)"
                                    />
                                </authority>
                                <authorityURI>
                                    <xsl:value-of
                                        select="normalize-space(id(substring-after(../../@scheme, '#'))/*:bibl/*:ref/@target)"
                                    />
                                </authorityURI>
                                <valueURI>
                                    <xsl:value-of select="*:ref/@target"/>
                                </valueURI>
                            </xsl:if>

                        </subject>

                    </xsl:if>

                </xsl:for-each>

                <!--subject can also appear as keywords - scriptorium specific for now?-->
                <xsl:for-each select="//*:profileDesc/*:textClass/*:keywords[@scheme='Topic']/*:term">

                    <xsl:if test="normalize-space(.)">

                        <subject>

                            <xsl:attribute name="display" select="'true'"/>

                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                            <fullForm>
                                <xsl:value-of select="normalize-space(.)"/>
                            </fullForm>

                        </subject>

                    </xsl:if>

                </xsl:for-each>



            </subjects>
        </xsl:if>

    </xsl:template>


    <!--EVENTS-->
    <xsl:template name="get-doc-events">

        <xsl:choose>
            <xsl:when
                test="//*:respStmt/*:name[@role='pbl'] and //*:sourceDesc/*:msDesc/*:history/*:origin">

                <!--publication-->
                <publications>

                    <xsl:attribute name="display" select="'true'"/>

                    <!--will there only ever be one of these?-->
                    <xsl:for-each select="//*:sourceDesc/*:msDesc/*:history/*:origin">
                        <event>

                            <type>publication</type>

                            <xsl:if test=".//*:origPlace">
                                <places>

                                    <xsl:attribute name="display" select="'true'"/>

                                    <xsl:for-each select=".//*:origPlace">
                                        <place>
                                            <xsl:attribute name="display" select="'true'"/>

                                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                                            <shortForm>
                                                <xsl:value-of select="normalize-space(.)"/>
                                            </shortForm>
                                            <fullForm>
                                                <xsl:value-of select="normalize-space(.)"/>
                                            </fullForm>
                                        </place>

                                    </xsl:for-each>
                                </places>
                            </xsl:if>

                            <xsl:for-each select=".//*:origDate[1]|.//*:date[1]">
                                <!-- filter by calendar? -->

                                <xsl:choose>
                                    <xsl:when test="@from">
                                        <dateStart>
                                            <xsl:value-of select="@from"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:when test="@notBefore">
                                        <dateStart>
                                            <xsl:value-of select="@notBefore"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:when test="@when">
                                        <dateStart>
                                            <xsl:value-of select="@when"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:otherwise> </xsl:otherwise>
                                </xsl:choose>

                                <xsl:choose>
                                    <xsl:when test="@to">
                                        <dateEnd>
                                            <xsl:value-of select="@to"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:when test="@notAfter">
                                        <dateEnd>
                                            <xsl:value-of select="@notBefore"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:when test="@when">
                                        <dateEnd>
                                            <xsl:value-of select="@when"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:otherwise> </xsl:otherwise>
                                </xsl:choose>

                                <dateDisplay>

                                    <xsl:attribute name="display" select="'true'"/>

                                    <!--<xsl:attribute name="displayForm" select="normalize-space(.)" />-->

                                    <xsl:variable name="dateDisplay">
                                        <xsl:apply-templates mode="html"/>
                                    </xsl:variable>

                                    <xsl:attribute name="displayForm" select="normalize-space($dateDisplay)"/>



                                    <xsl:value-of select="normalize-space(.)"/>



                                </dateDisplay>


                            </xsl:for-each>

                            <publishers>
                                <xsl:attribute name="display" select="'true'"/>

                                <xsl:apply-templates select="//*:respStmt/*:name[@role='pbl']"
                                                     mode="publisher"/>

                            </publishers>


                        </event>
                    </xsl:for-each>



                </publications>



            </xsl:when>

            <xsl:when
                test="//*:sourceDesc/*:msDesc/*:history/*:origin or exists(//*:sourceDesc/*:msDesc/*:msPart/*:history/*:origin)">


                <!--creation-->
                <creations>

                    <xsl:attribute name="display" select="'true'"/>
                    <!--will there only ever be one of these?-->
                    <xsl:for-each select="//*:sourceDesc/*:msDesc/*:history/*:origin">
                        <event>

                            <type>creation</type>

                            <xsl:if test=".//*:origPlace">
                                <places>

                                    <xsl:attribute name="display" select="'true'"/>

                                    <xsl:for-each select=".//*:origPlace">
                                        <place>
                                            <xsl:attribute name="display" select="'true'"/>

                                            <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                                            <shortForm>
                                                <xsl:value-of select="normalize-space(.)"/>
                                            </shortForm>
                                            <fullForm>
                                                <xsl:value-of select="normalize-space(.)"/>
                                            </fullForm>
                                        </place>

                                    </xsl:for-each>
                                </places>
                            </xsl:if>

                            <xsl:for-each select=".//*:origDate[1]|.//*:date[1]">
                                <!-- filter by calendar? -->

                                <xsl:choose>
                                    <xsl:when test="@from">
                                        <dateStart>
                                            <xsl:value-of select="@from"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:when test="@notBefore">
                                        <dateStart>
                                            <xsl:value-of select="@notBefore"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:when test="@when">
                                        <dateStart>
                                            <xsl:value-of select="@when"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:otherwise> </xsl:otherwise>
                                </xsl:choose>

                                <xsl:choose>
                                    <xsl:when test="@to">
                                        <dateEnd>
                                            <xsl:value-of select="@to"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:when test="@notAfter">
                                        <dateEnd>
                                            <xsl:value-of select="@notBefore"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:when test="@when">
                                        <dateEnd>
                                            <xsl:value-of select="@when"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:otherwise> </xsl:otherwise>
                                </xsl:choose>

                                <dateDisplay>

                                    <xsl:attribute name="display" select="'true'"/>

                                    <!--<xsl:attribute name="displayForm" select="normalize-space(.)" />-->

                                    <xsl:variable name="dateDisplay">
                                        <xsl:apply-templates mode="html"/>
                                    </xsl:variable>

                                    <xsl:attribute name="displayForm" select="normalize-space($dateDisplay)"/>



                                    <xsl:value-of select="normalize-space(.)"/>



                                </dateDisplay>


                            </xsl:for-each>
                        </event>
                    </xsl:for-each>

                    <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart/*:history/*:origin">
                        <event>

                            <type>creation</type>

                            <xsl:if test=".//*:origPlace">
                                <places>

                                    <xsl:attribute name="display" select="'true'"/>

                                    <xsl:for-each select=".//*:origPlace">
                                        <place>
                                            <xsl:attribute name="display" select="'true'"/>

                                            <xsl:variable name="place">
                                                <xsl:for-each select="../../../*:altIdentifier/*:idno">

                                                    <xsl:text>&lt;b&gt;</xsl:text>
                                                    <xsl:apply-templates mode="html"/>
                                                    <xsl:text>:</xsl:text>
                                                    <xsl:text>&lt;/b&gt;</xsl:text>
                                                    <xsl:text> </xsl:text>

                                                </xsl:for-each>

                                                <xsl:value-of select="normalize-space(.)"/>

                                            </xsl:variable>

                                            <xsl:attribute name="displayForm" select="normalize-space($place)"/>

                                            <shortForm>
                                                <xsl:value-of select="normalize-space(.)"/>
                                            </shortForm>
                                        </place>

                                    </xsl:for-each>
                                </places>
                            </xsl:if>

                            <xsl:for-each select=".//*:origDate[1]|.//*:date[1]">
                                <!-- filter by calendar? -->

                                <xsl:choose>
                                    <xsl:when test="@from">
                                        <dateStart>
                                            <xsl:value-of select="@from"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:when test="@notBefore">
                                        <dateStart>
                                            <xsl:value-of select="@notBefore"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:when test="@when">
                                        <dateStart>
                                            <xsl:value-of select="@when"/>
                                        </dateStart>
                                    </xsl:when>
                                    <xsl:otherwise> </xsl:otherwise>
                                </xsl:choose>

                                <xsl:choose>
                                    <xsl:when test="@to">
                                        <dateEnd>
                                            <xsl:value-of select="@to"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:when test="@notAfter">
                                        <dateEnd>
                                            <xsl:value-of select="@notBefore"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:when test="@when">
                                        <dateEnd>
                                            <xsl:value-of select="@when"/>
                                        </dateEnd>
                                    </xsl:when>
                                    <xsl:otherwise> </xsl:otherwise>
                                </xsl:choose>

                                <dateDisplay>

                                    <xsl:attribute name="display" select="'true'"/>

                                    <xsl:variable name="date">
                                        <xsl:for-each select="../../../*:altIdentifier/*:idno">

                                            <xsl:text>&lt;b&gt;</xsl:text>
                                            <xsl:apply-templates mode="html"/>
                                            <xsl:text>:</xsl:text>
                                            <xsl:text>&lt;/b&gt;</xsl:text>
                                            <xsl:text> </xsl:text>

                                        </xsl:for-each>

                                        <xsl:value-of select="normalize-space(.)"/>

                                    </xsl:variable>

                                    <xsl:attribute name="displayForm" select="normalize-space($date)"/>

                                    <xsl:value-of select="normalize-space(.)"/>
                                </dateDisplay>

                            </xsl:for-each>
                        </event>
                    </xsl:for-each>

                </creations>
            </xsl:when>

        </xsl:choose>


        <!--acquisition-->
        <xsl:if test="//*:sourceDesc/*:msDesc/*:history/*:acquisition">

            <acquisitions>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="//*:sourceDesc/*:msDesc/*:history/*:acquisition">
                    <event>

                        <type>acquisition</type>

                        <xsl:for-each select=".//*:date[1]">

                            <xsl:choose>
                                <xsl:when test="@from">
                                    <dateStart>
                                        <xsl:value-of select="@from"/>
                                    </dateStart>
                                </xsl:when>
                                <xsl:when test="@notBefore">
                                    <dateStart>
                                        <xsl:value-of select="@notBefore"/>
                                    </dateStart>
                                </xsl:when>
                                <xsl:when test="@when">
                                    <dateStart>
                                        <xsl:value-of select="@when"/>
                                    </dateStart>
                                </xsl:when>
                                <xsl:otherwise> </xsl:otherwise>
                            </xsl:choose>

                            <xsl:choose>
                                <xsl:when test="@to">
                                    <dateEnd>
                                        <xsl:value-of select="@to"/>
                                    </dateEnd>
                                </xsl:when>
                                <xsl:when test="@notAfter">
                                    <dateEnd>
                                        <xsl:value-of select="@notBefore"/>
                                    </dateEnd>
                                </xsl:when>
                                <xsl:when test="@when">
                                    <dateEnd>
                                        <xsl:value-of select="@when"/>
                                    </dateEnd>
                                </xsl:when>
                                <xsl:otherwise> </xsl:otherwise>
                            </xsl:choose>

                            <dateDisplay>

                                <xsl:attribute name="display" select="'true'"/>

                                <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                                <xsl:value-of select="normalize-space(.)"/>
                            </dateDisplay>

                        </xsl:for-each>
                    </event>
                </xsl:for-each>

            </acquisitions>
        </xsl:if>

    </xsl:template>


    <xsl:template match="//*:respStmt/*:name[@role='pbl']" mode="publisher">

        <publisher>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:choose>
                <xsl:when test="normalize-space(*:persName[@type='standard'])">
                    <xsl:attribute name="displayForm"
                                   select="normalize-space(*:persName[@type='standard'])"/>

                    <xsl:value-of select="normalize-space(*:persName[@type='standard'])"/>

                </xsl:when>
                <xsl:when test="normalize-space(*:orgName[@type='standard'])">
                    <xsl:attribute name="displayForm"
                                   select="normalize-space(*:orgName[@type='standard'])"/>

                    <xsl:value-of select="normalize-space(*:orgName[@type='standard'])"/>

                </xsl:when>
                <xsl:when test="normalize-space(*:orgName[1])">
                    <xsl:attribute name="displayForm" select="normalize-space(*:orgName[1])"/>

                    <xsl:value-of select="normalize-space(*:orgName[1])"/>

                </xsl:when>
                <xsl:otherwise>

                    <xsl:attribute name="displayForm" select="normalize-space(*:persName[1])"/>

                    <xsl:value-of select="normalize-space(*:persName[1])"/>
                </xsl:otherwise>
            </xsl:choose>

        </publisher>


    </xsl:template>

    <!--LOCATION AND CLASSMARK-->
    <xsl:template name="get-doc-physloc">

        <physicalLocation>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:attribute name="displayForm"
                           select="normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:repository)"/>

            <xsl:value-of select="normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:repository)"/>

        </physicalLocation>

        <shelfLocator>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:attribute name="displayForm"
                           select="normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:idno)"/>

            <xsl:value-of select="normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:idno)"/>

        </shelfLocator>

    </xsl:template>

    <!--ALTERNATIVE IDENTIFIERS-->
    <xsl:template name="get-doc-alt-ids">

        <xsl:if
            test="normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:altIdentifier[not(@type='internal')][1]/*:idno)">

            <altIdentifiers>

                <xsl:attribute name="display" select="'true'"/>


                <xsl:for-each
                    select="//*:sourceDesc/*:msDesc/*:msIdentifier/*:altIdentifier[not(@type='internal')]/*:idno">

                    <altIdentifier>
                        <xsl:attribute name="display" select="'true'"/>
                        <xsl:attribute name="displayForm" select="normalize-space(.)"/>

                        <xsl:value-of select="normalize-space(.)"/>


                    </altIdentifier>



                </xsl:for-each>

            </altIdentifiers>

        </xsl:if>

    </xsl:template>


    <!--THUMBNAIL-->
    <xsl:template name="get-doc-thumbnail">


        <xsl:variable name="graphic" select="//*:graphic[@decls='#document-thumbnail']"/>

        <xsl:if test="$graphic">

            <thumbnailUrl>
                <xsl:value-of select="normalize-space($graphic/@url)"/>
            </thumbnailUrl>

            <thumbnailOrientation>
                <xsl:choose>
                    <xsl:when test="$graphic/@rend = 'portrait'">
                        <xsl:value-of select="'portrait'"/>
                    </xsl:when>
                    <xsl:when test="$graphic/@rend = 'landscape'">
                        <xsl:value-of select="'landscape'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="'portrait'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </thumbnailOrientation>

        </xsl:if>

    </xsl:template>



    <!-- RIGHTS-->
    <xsl:template name="get-doc-image-rights">

        <displayImageRights>
            <xsl:value-of
                select="normalize-space(//*:publicationStmt/*:availability[@xml:id='displayImageRights'])"
            />
        </displayImageRights>

        <downloadImageRights>
            <xsl:value-of
                select="normalize-space(//*:publicationStmt/*:availability[@xml:id='downloadImageRights'])"
            />
        </downloadImageRights>

        <imageReproPageURL>
            <xsl:value-of
                select="cudl:get-imageReproPageURL(normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:repository), normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:idno))"
            />
        </imageReproPageURL>

    </xsl:template>

    <xsl:template name="get-doc-metadata-rights">

        <metadataRights>
            <xsl:value-of
                select="normalize-space(//*:publicationStmt/*:availability[@xml:id='metadataRights'])"/>
        </metadataRights>

    </xsl:template>

    <!--AUTHORITY-->
    <xsl:template name="get-doc-authority">

        <docAuthority>

            <xsl:variable name="authority">
                <xsl:apply-templates select="//*:publicationStmt/*:authority" mode="html"/>

            </xsl:variable>

            <xsl:value-of select="normalize-space($authority)"/>

        </docAuthority>

    </xsl:template>

    <xsl:template match="*:authority" mode="html">
        <xsl:apply-templates mode="html"/>
    </xsl:template>

    <!--COMPLETENESS-->

    <xsl:template match="*:note[@type='completeness']">
        <completeness>

            <xsl:value-of select="normalize-space(.)"/>
        </completeness>
    </xsl:template>

    <!--FUNDING-->
    <xsl:template name="get-doc-funding">

        <fundings>

            <xsl:variable name="funding">
                <xsl:apply-templates select="//*:titleStmt/*:funder" mode="html"/>
            </xsl:variable>

            <xsl:attribute name="display" select="'true'"/>
            <funding>
                <xsl:attribute name="display" select="'true'"/>
                <xsl:attribute name="displayForm" select="normalize-space($funding)"/>
                <xsl:value-of select="normalize-space($funding)"/>
            </funding>
        </fundings>

    </xsl:template>

    <!--PHYSICAL DESCRIPTION-->
    <!--general physical description either in p tag or a list - often used as a general summary for composite manuscripts where physDesc has msParts-->
    <xsl:template name="get-doc-physdesc">

        <xsl:if
            test="exists(//*:sourceDesc/*:msDesc/*:physDesc/*:p|//*:sourceDesc/*:msDesc/*:physDesc/*:list) or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:p|//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:list)">

            <physdesc>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="physdesc">
                    <xsl:apply-templates
                        select="//*:sourceDesc/*:msDesc/*:physDesc/*:p|//*:sourceDesc/*:msDesc/*:physDesc/*:list"
                        mode="html"/>

                    <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                        <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                            <xsl:if test="exists(*:physDesc/*:p|*:physDesc/*:list)">

                                <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                <xsl:for-each select="*:altIdentifier/*:idno">

                                    <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                    <xsl:text>&lt;b&gt;</xsl:text>
                                    <xsl:apply-templates mode="html"/>
                                    <xsl:text>:</xsl:text>
                                    <xsl:text>&lt;/b&gt;</xsl:text>
                                    <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                    <xsl:text>&lt;br /&gt;</xsl:text>

                                </xsl:for-each>

                                <xsl:apply-templates select="*:physDesc/*:p|*:physDesc/*:list" mode="html"/>

                                <xsl:text>&lt;/div&gt;</xsl:text>

                            </xsl:if>

                        </xsl:for-each>

                        <xsl:text>&lt;/div&gt;</xsl:text>

                    </xsl:if>

                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($physdesc)"/>

                <!-- <xsl:value-of select="normalize-space($physdesc)" /> -->
                <xsl:value-of select="normalize-space(replace($physdesc, '&lt;[^&gt;]+&gt;', ''))"/>

            </physdesc>

        </xsl:if>

        <xsl:if
            test="normalize-space(//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/@form) or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:objectDesc/@form)">

            <form>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="form">
                    <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/@form"
                                         mode="html"/>


                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($form)"/>

                <xsl:value-of select="normalize-space(replace($form, '&lt;[^&gt;]+&gt;', ''))"/>

            </form>

        </xsl:if>

        <xsl:if
            test="normalize-space(//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:support) or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:objectDesc/*:supportDesc/*:support)">

            <material>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="material">
                    <xsl:apply-templates
                        select="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:support"
                        mode="html"/>

                    <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                        <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                            <xsl:if test="normalize-space(*:physDesc/*:objectDesc/*:supportDesc/*:support)">

                                <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                <xsl:for-each select="*:altIdentifier/*:idno">

                                    <!-- <xsl:text> </xsl:text> -->
                                    <xsl:text>&lt;b&gt;</xsl:text>
                                    <xsl:apply-templates mode="html"/>
                                    <xsl:text>:</xsl:text>
                                    <xsl:text>&lt;/b&gt;</xsl:text>
                                    <xsl:text> </xsl:text>

                                </xsl:for-each>

                                <xsl:apply-templates
                                    select="*:physDesc/*:objectDesc/*:supportDesc/*:support" mode="html"/>

                                <xsl:text>&lt;/div&gt;</xsl:text>

                            </xsl:if>

                        </xsl:for-each>

                        <xsl:text>&lt;/div&gt;</xsl:text>

                    </xsl:if>

                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($material)"/>

                <!-- <xsl:value-of select="normalize-space($material)" /> -->
                <xsl:value-of select="normalize-space(replace($material, '&lt;[^&gt;]+&gt;', ''))"/>

            </material>

        </xsl:if>

        <xsl:if
            test="normalize-space(//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:extent) or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:objectDesc/*:supportDesc/*:extent)">

            <extent>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="extent">
                    <xsl:apply-templates
                        select="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:extent"
                        mode="html"/>

                    <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                        <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                            <xsl:if test="normalize-space(*:physDesc/*:objectDesc/*:supportDesc/*:extent)">

                                <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                <xsl:for-each select="*:altIdentifier/*:idno">

                                    <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                    <xsl:text>&lt;b&gt;</xsl:text>
                                    <xsl:apply-templates mode="html"/>
                                    <xsl:text>:</xsl:text>
                                    <xsl:text>&lt;/b&gt;</xsl:text>
                                    <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                    <xsl:text> </xsl:text>

                                </xsl:for-each>

                                <xsl:apply-templates select="*:physDesc/*:objectDesc/*:supportDesc/*:extent"
                                                     mode="html"/>

                                <xsl:text>&lt;/div&gt;</xsl:text>

                            </xsl:if>

                        </xsl:for-each>

                        <xsl:text>&lt;/div&gt;</xsl:text>
                    </xsl:if>

                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($extent)"/>

                <!-- <xsl:value-of select="normalize-space($extent)" /> -->
                <xsl:value-of select="normalize-space(replace($extent, '&lt;[^&gt;]+&gt;', ''))"/>

            </extent>

        </xsl:if>

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:foliation or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:objectDesc/*:supportDesc/*:foliation)">

            <foliation>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="foliation">
                    <xsl:apply-templates
                        select="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:foliation"
                        mode="html"/>

                    <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                        <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                            <xsl:if test="*:physDesc/*:objectDesc/*:supportDesc/*:foliation">

                                <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                <xsl:for-each select="*:altIdentifier/*:idno">

                                    <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                    <xsl:text>&lt;b&gt;</xsl:text>
                                    <xsl:apply-templates mode="html"/>
                                    <xsl:text>:</xsl:text>
                                    <xsl:text>&lt;/b&gt;</xsl:text>
                                    <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                    <xsl:text>&lt;br /&gt;</xsl:text>

                                </xsl:for-each>

                                <xsl:apply-templates
                                    select="*:physDesc/*:objectDesc/*:supportDesc/*:foliation" mode="html"/>

                                <xsl:text>&lt;/div&gt;</xsl:text>

                            </xsl:if>

                        </xsl:for-each>

                        <xsl:text>&lt;/div&gt;</xsl:text>

                    </xsl:if>

                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($foliation)"/>
                <!-- <xsl:value-of select="normalize-space($foliation)" /> -->
                <xsl:value-of select="normalize-space(replace($foliation, '&lt;[^&gt;]+&gt;', ''))"/>

            </foliation>

        </xsl:if>


        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:collation or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:objectDesc/*:supportDesc/*:collation)">

            <collation>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="collation">
                    <xsl:apply-templates
                        select="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:collation"
                        mode="html"/>

                    <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                        <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                            <xsl:if test="*:physDesc/*:objectDesc/*:supportDesc/*:collation">

                                <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                <xsl:for-each select="*:altIdentifier/*:idno">

                                    <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                    <xsl:text>&lt;b&gt;</xsl:text>
                                    <xsl:apply-templates mode="html"/>
                                    <xsl:text>:</xsl:text>
                                    <xsl:text>&lt;/b&gt;</xsl:text>
                                    <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                    <xsl:text>&lt;br /&gt;</xsl:text>

                                </xsl:for-each>

                                <xsl:apply-templates
                                    select="*:physDesc/*:objectDesc/*:supportDesc/*:collation" mode="html"/>

                                <xsl:text>&lt;/div&gt;</xsl:text>

                            </xsl:if>

                        </xsl:for-each>

                        <xsl:text>&lt;/div&gt;</xsl:text>

                    </xsl:if>

                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($collation)"/>
                <xsl:value-of select="normalize-space(replace($collation, '&lt;[^&gt;]+&gt;', ''))"/>

            </collation>

        </xsl:if>


        <xsl:if
            test="normalize-space(//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:condition) or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:objectDesc/*:supportDesc/*:condition)">

            <conditions>

                <xsl:attribute name="display" select="'true'"/>

                <condition>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="condition">
                        <xsl:apply-templates
                            select="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:supportDesc/*:condition"
                            mode="html"/>

                        <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                            <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                            <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                                <xsl:if
                                    test="normalize-space(*:physDesc/*:objectDesc/*:supportDesc/*:condition)">

                                    <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                    <xsl:for-each select="*:altIdentifier/*:idno">

                                        <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                        <xsl:text>&lt;b&gt;</xsl:text>
                                        <xsl:apply-templates mode="html"/>
                                        <xsl:text>:</xsl:text>
                                        <xsl:text>&lt;/b&gt;</xsl:text>
                                        <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                        <xsl:text>&lt;br /&gt;</xsl:text>

                                    </xsl:for-each>

                                    <xsl:apply-templates
                                        select="*:physDesc/*:objectDesc/*:supportDesc/*:condition" mode="html"/>

                                    <xsl:text>&lt;/div&gt;</xsl:text>

                                </xsl:if>

                            </xsl:for-each>

                            <xsl:text>&lt;/div&gt;</xsl:text>

                        </xsl:if>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($condition)"/>

                    <!-- <xsl:value-of select="normalize-space($condition)" /> -->
                    <xsl:value-of select="normalize-space(replace($condition, '&lt;[^&gt;]+&gt;', ''))"/>

                </condition>

            </conditions>

        </xsl:if>

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:layoutDesc or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:objectDesc/*:layoutDesc)">

            <layouts>

                <xsl:attribute name="display" select="'true'"/>

                <layout>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="layout">
                        <xsl:apply-templates
                            select="//*:sourceDesc/*:msDesc/*:physDesc/*:objectDesc/*:layoutDesc"
                            mode="html"/>

                        <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                            <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                            <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                                <xsl:if test="*:physDesc/*:objectDesc/*:layoutDesc">

                                    <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                    <xsl:for-each select="*:altIdentifier/*:idno">

                                        <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                        <xsl:text>&lt;b&gt;</xsl:text>
                                        <xsl:apply-templates mode="html"/>
                                        <xsl:text>:</xsl:text>
                                        <xsl:text>&lt;/b&gt;</xsl:text>
                                        <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                        <xsl:text>&lt;br /&gt;</xsl:text>

                                    </xsl:for-each>

                                    <xsl:apply-templates select="*:physDesc/*:objectDesc/*:layoutDesc"
                                                         mode="html"/>

                                    <xsl:text>&lt;/div&gt;</xsl:text>

                                </xsl:if>

                            </xsl:for-each>

                            <xsl:text>&lt;/div&gt;</xsl:text>

                        </xsl:if>

                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($layout)"/>

                    <!-- <xsl:value-of select="normalize-space($layout)" /> -->
                    <xsl:value-of select="normalize-space(replace($layout, '&lt;[^&gt;]+&gt;', ''))"/>

                </layout>

            </layouts>

        </xsl:if>

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:physDesc/*:handDesc or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:handDesc)">

            <scripts>

                <xsl:attribute name="display" select="'true'"/>

                <script>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="script">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:physDesc/*:handDesc" mode="html"/>

                        <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                            <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                            <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                                <xsl:if test="*:physDesc/*:handDesc">

                                    <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                    <xsl:for-each select="*:altIdentifier/*:idno">

                                        <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                        <xsl:text>&lt;b&gt;</xsl:text>
                                        <xsl:apply-templates mode="html"/>
                                        <xsl:text>:</xsl:text>
                                        <xsl:text>&lt;/b&gt;</xsl:text>
                                        <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                        <xsl:text>&lt;br /&gt;</xsl:text>

                                    </xsl:for-each>

                                    <xsl:apply-templates select="*:physDesc/*:handDesc" mode="html"/>

                                    <xsl:text>&lt;/div&gt;</xsl:text>

                                </xsl:if>

                            </xsl:for-each>

                            <xsl:text>&lt;/div&gt;</xsl:text>

                        </xsl:if>

                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($script)"/>

                    <!-- <xsl:value-of select="normalize-space($script)" /> -->
                    <xsl:value-of select="normalize-space(replace($script, '&lt;[^&gt;]+&gt;', ''))"/>

                </script>

            </scripts>

        </xsl:if>


        <xsl:if test="//*:sourceDesc/*:msDesc/*:physDesc/*:musicNotation">

            <musicNotations>

                <xsl:attribute name="display" select="'true'"/>

                <musicNotation>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="musicNotation">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:physDesc/*:musicNotation"
                                             mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($musicNotation)"/>

                    <!-- <xsl:value-of select="normalize-space($binding)" /> -->
                    <xsl:value-of
                        select="normalize-space(replace($musicNotation, '&lt;[^&gt;]+&gt;', ''))"/>

                </musicNotation>

            </musicNotations>

        </xsl:if>


        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:physDesc/*:decoDesc or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:decoDesc)">

            <decorations>

                <xsl:attribute name="display" select="'true'"/>

                <decoration>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="decoration">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:physDesc/*:decoDesc"
                                             mode="html"/>

                        <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                            <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                            <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                                <xsl:if test="*:physDesc/*:decoDesc">

                                    <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                    <xsl:for-each select="*:altIdentifier/*:idno">

                                        <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                        <xsl:text>&lt;b&gt;</xsl:text>
                                        <xsl:apply-templates mode="html"/>
                                        <xsl:text>:</xsl:text>
                                        <xsl:text>&lt;/b&gt;</xsl:text>
                                        <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                        <xsl:text>&lt;br /&gt;</xsl:text>

                                    </xsl:for-each>

                                    <xsl:apply-templates select="*:physDesc/*:decoDesc" mode="html"/>

                                    <xsl:text>&lt;/div&gt;</xsl:text>

                                </xsl:if>

                            </xsl:for-each>

                            <xsl:text>&lt;/div&gt;</xsl:text>

                        </xsl:if>

                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($decoration)"/>

                    <!-- <xsl:value-of select="normalize-space($decoration)" /> -->
                    <xsl:value-of select="normalize-space(replace($decoration, '&lt;[^&gt;]+&gt;', ''))"/>

                </decoration>

            </decorations>

        </xsl:if>

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:physDesc/*:additions or exists(//*:sourceDesc/*:msDesc/*:msPart/*:physDesc/*:additions)">

            <additions>

                <xsl:attribute name="display" select="'true'"/>

                <addition>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="addition">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:physDesc/*:additions"
                                             mode="html"/>

                        <xsl:if test="exists(//*:sourceDesc/*:msDesc/*:msPart)">

                            <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>

                            <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msPart">

                                <xsl:if test="*:physDesc/*:additions">

                                    <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>

                                    <xsl:for-each select="*:altIdentifier/*:idno">

                                        <!-- <xsl:text>&lt;p&gt;</xsl:text> -->
                                        <xsl:text>&lt;b&gt;</xsl:text>
                                        <xsl:apply-templates mode="html"/>
                                        <xsl:text>:</xsl:text>
                                        <xsl:text>&lt;/b&gt;</xsl:text>
                                        <!-- <xsl:text>&lt;/p&gt;</xsl:text> -->
                                        <xsl:text>&lt;br /&gt;</xsl:text>

                                    </xsl:for-each>

                                    <xsl:apply-templates select="*:physDesc/*:additions" mode="html"/>

                                    <xsl:text>&lt;/div&gt;</xsl:text>

                                </xsl:if>

                            </xsl:for-each>

                            <xsl:text>&lt;/div&gt;</xsl:text>

                        </xsl:if>

                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($addition)"/>

                    <!-- <xsl:value-of select="normalize-space($addition)" /> -->
                    <xsl:value-of select="normalize-space(replace($addition, '&lt;[^&gt;]+&gt;', ''))"/>

                </addition>

            </additions>

        </xsl:if>

        <xsl:if test="//*:sourceDesc/*:msDesc/*:physDesc/*:bindingDesc">

            <bindings>

                <xsl:attribute name="display" select="'true'"/>

                <binding>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="binding">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:physDesc/*:bindingDesc"
                                             mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($binding)"/>

                    <!-- <xsl:value-of select="normalize-space($binding)" /> -->
                    <xsl:value-of select="normalize-space(replace($binding, '&lt;[^&gt;]+&gt;', ''))"/>

                </binding>

            </bindings>

        </xsl:if>

        <xsl:if test="//*:sourceDesc/*:msDesc/*:physDesc/*:accMat">

            <accMats>

                <xsl:attribute name="display" select="'true'"/>

                <accMat>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="accMat">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:physDesc/*:accMat"
                                             mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($accMat)"/>

                    <!-- <xsl:value-of select="normalize-space($binding)" /> -->
                    <xsl:value-of select="normalize-space(replace($accMat, '&lt;[^&gt;]+&gt;', ''))"/>

                </accMat>

            </accMats>

        </xsl:if>



    </xsl:template>

    <!--physical description processing templates-->
    <xsl:template match="*:objectDesc/@form" mode="html">


        <xsl:value-of select="concat(upper-case(substring(., 1, 1)), substring(., 2))"/>
        <!--<xsl:value-of select="normalize-space(.)" />-->
        <!--<xsl:text>.</xsl:text>-->

    </xsl:template>

    <xsl:template match="*:supportDesc/*:support" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:supportDesc/*:extent" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:supportDesc/*:foliation" mode="html">

        <xsl:text>&lt;p&gt;</xsl:text>

        <xsl:if test="@n">
            <xsl:value-of select="@n"/>
            <xsl:text>. </xsl:text>
        </xsl:if>

        <xsl:if test="@type">
            <xsl:value-of select="cudl:first-upper-case(@type)"/>
            <xsl:text>: </xsl:text>
        </xsl:if>

        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;/p&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:supportDesc/*:condition" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:dimensions" mode="html">

        <!--      <xsl:text>&lt;br /&gt;</xsl:text> -->

        <xsl:if test="@subtype">
            <xsl:text>&lt;b&gt;</xsl:text>
            <xsl:value-of select="cudl:first-upper-case(translate(@subtype, '_', ' '))"/>
            <xsl:text>:</xsl:text>
            <xsl:text>&lt;/b&gt;</xsl:text>
            <xsl:text> </xsl:text>
        </xsl:if>

        <xsl:text> </xsl:text>
        <xsl:value-of select="cudl:first-upper-case(@type)"/>
        <xsl:text> </xsl:text>
        <xsl:for-each select="*">

            <xsl:choose>
                <xsl:when test="local-name(.) = 'dim'">
                    <xsl:value-of select="@type"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="local-name(.)"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:text>: </xsl:text>

            <xsl:choose>
                <xsl:when test="normalize-space(.)">
                    <xsl:value-of select="."/>
                </xsl:when>
                <xsl:when test="normalize-space(@quantity)">
                    <xsl:value-of select="@quantity"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- shouldn't happen? -->
                </xsl:otherwise>
            </xsl:choose>

            <xsl:if test="../@unit">
                <xsl:text> </xsl:text>
                <xsl:value-of select="../@unit"/>
            </xsl:if>

            <xsl:if test="not(position()=last())">
                <xsl:text>, </xsl:text>
            </xsl:if>

        </xsl:for-each>

        <xsl:text>. </xsl:text>


    </xsl:template>

    <xsl:template match="*:layoutDesc" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:layout" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:commentaryForm" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:text>&lt;b&gt;Commentary form:&lt;/b&gt; </xsl:text>
        <xsl:value-of select="@type"/>
        <xsl:text>. </xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:stringHole" mode="html">


        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:handDesc" mode="html">

        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:handNote" mode="html">



        <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:decoDesc" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:decoNote" mode="html">

        <xsl:apply-templates mode="html"/>

        <xsl:if test="exists(following-sibling::*)">
            <xsl:text>&lt;br /&gt;</xsl:text>
        </xsl:if>

    </xsl:template>

    <xsl:template match="*:additions" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:bindingDesc" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:accMat" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>


    <!--provenance-->
    <xsl:template name="get-doc-history">

        <xsl:if test="//*:sourceDesc/*:msDesc/*:history/*:provenance">

            <provenances>

                <xsl:attribute name="display" select="'true'"/>

                <provenance>
                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="provenance">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:history/*:provenance"
                                             mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($provenance)"/>

                    <xsl:value-of select="normalize-space(replace($provenance, '&lt;[^&gt;]+&gt;', ''))"/>

                </provenance>

            </provenances>

        </xsl:if>

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:history/*:origin/text()|//*:sourceDesc/*:msDesc/*:history/*:origin/*:p">

            <origins>

                <xsl:attribute name="display" select="'true'"/>

                <origin>
                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="origin">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:history/*:origin"
                                             mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($origin)"/>

                    <xsl:value-of select="normalize-space(replace($origin, '&lt;[^&gt;]+&gt;', ''))"/>

                </origin>

            </origins>

        </xsl:if>

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:history/*:acquisition/text()|//*:sourceDesc/*:msDesc/*:history/*:acquisition/*:p">

            <acquisitionTexts>

                <xsl:attribute name="display" select="'true'"/>

                <acquisitionText>
                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="acquisition">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:history/*:acquisition"
                                             mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($acquisition)"/>

                    <xsl:value-of select="normalize-space(replace($acquisition, '&lt;[^&gt;]+&gt;', ''))"/>

                </acquisitionText>

            </acquisitionTexts>

        </xsl:if>



    </xsl:template>





    <xsl:template match="*:history/*:provenance" mode="html">

        <xsl:if test="normalize-space(.)">

            <xsl:apply-templates mode="html"/>

        </xsl:if>

    </xsl:template>


    <xsl:template match="*:history/*:origin" mode="html">

        <xsl:if test="normalize-space(.)">

            <xsl:apply-templates mode="html"/>

        </xsl:if>

    </xsl:template>


    <xsl:template match="*:history/*:acquisition" mode="html">

        <xsl:if test="normalize-space(.)">

            <xsl:apply-templates mode="html"/>

        </xsl:if>

    </xsl:template>

    <!--***********************************EXCERPTS - bits of transcription-->
    <xsl:template name="get-item-excerpts">


        <xsl:if
            test="*:head|*:div/*:head|*:p|*:div/*:p|*:div/*:note|*:colophon|*:div/*:colophon|*:decoNote|*:div/*:decoNote|*:explicit|*:div/*:explicit|*:finalRubric|*:div/*:finalRubric|*:incipit|*:div/*:incipit|*:rubric|*:div/*:rubric">
            <excerpts>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="excerpts">
                    <xsl:apply-templates
                        select="*:head|*:div/*:head|*:p|*:div/*:p|*:div/*:note|*:colophon|*:div/*:colophon|*:decoNote|*:div/*:decoNote|*:explicit|*:div/*:explicit|*:finalRubric|*:div/*:finalRubric|*:incipit|*:div/*:incipit|*:rubric|*:div/*:rubric"
                        mode="html"/>
                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($excerpts)"/>
                <!-- <xsl:value-of select="normalize-space($excerpts)" /> -->
                <xsl:value-of select="normalize-space(replace($excerpts, '&lt;[^&gt;]+&gt;', ''))"/>
            </excerpts>
        </xsl:if>

    </xsl:template>

    <!--NOTES-->
    <xsl:template name="get-doc-notes">


        <xsl:if test="//*:history/*:origin/*:note">
            <notes>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="//*:history/*:origin/*:note">

                    <xsl:variable name="note">
                        <xsl:apply-templates mode="html"/>
                    </xsl:variable>

                    <note>
                        <xsl:attribute name="display" select="'true'"/>
                        <xsl:attribute name="displayForm" select="normalize-space($note)"/>
                        <xsl:value-of select="normalize-space($note)"/>
                    </note>

                </xsl:for-each>

            </notes>
        </xsl:if>

    </xsl:template>


    <xsl:template name="get-item-notes">


        <xsl:if test="*:note">
            <notes>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="*:note">

                    <xsl:variable name="note">
                        <xsl:apply-templates mode="html"/>
                    </xsl:variable>

                    <note>
                        <xsl:attribute name="display" select="'true'"/>
                        <xsl:attribute name="displayForm" select="normalize-space($note)"/>
                        <xsl:value-of select="normalize-space($note)"/>
                    </note>

                </xsl:for-each>

            </notes>
        </xsl:if>

    </xsl:template>

    <!--COLOPHON-->
    <xsl:template match="*:msItem/*:colophon|*:msItem/*:div/*:colophon" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:text>&lt;b&gt;Colophon</xsl:text>

        <xsl:if test="normalize-space(@type)">
            <xsl:value-of select="concat(', ', normalize-space(@type))"/>
        </xsl:if>

        <xsl:text>:&lt;/b&gt; </xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <!--EXPLICIT-->
    <xsl:template match="*:msItem/*:explicit|*:msItem/*:div/*:explicit" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:text>&lt;b&gt;Explicit</xsl:text>

        <xsl:if test="normalize-space(@type)">
            <xsl:value-of select="concat(', ', normalize-space(@type))"/>
        </xsl:if>

        <xsl:text>:&lt;/b&gt; </xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>


    <!--INCIPIT-->
    <xsl:template match="*:msItem/*:incipit|*:msItem/*:div/*:incipit" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:text>&lt;b&gt;Incipit</xsl:text>

        <xsl:if test="normalize-space(@type)">
            <xsl:value-of select="concat(', ', normalize-space(@type))"/>
        </xsl:if>

        <xsl:text>:&lt;/b&gt; </xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <!--INCIPIT as title-->
    <xsl:template match="*:incipit" mode="title">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <!--RUBRIC as title-->
    <xsl:template match="*:rubric" mode="title">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <!--RUBRIC-->
    <xsl:template match="*:msItem/*:rubric|*:msItem/*:div/*:rubric" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:text>&lt;b&gt;Rubric</xsl:text>

        <xsl:if test="normalize-space(@type)">
            <xsl:value-of select="concat(', ', normalize-space(@type))"/>
        </xsl:if>

        <xsl:text>:&lt;/b&gt; </xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:msItem/*:finalRubric|*:msItem/*:div/*:finalRubric" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:text>&lt;b&gt;Final Rubric</xsl:text>

        <xsl:if test="normalize-space(@type)">
            <xsl:value-of select="concat(', ', normalize-space(@type))"/>
        </xsl:if>

        <xsl:text>:&lt;/b&gt; </xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <!--****************************notes-->
    <xsl:template match="*:note" mode="html">


        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <!--deco notes within msitems-->
    <xsl:template match="*:msItem//*:decoNote" mode="html">

        <xsl:choose>
            <xsl:when test="*:p">

                <xsl:text>&lt;p&gt;</xsl:text>
                <xsl:text>&lt;b&gt;Decoration:&lt;/b&gt; </xsl:text>
                <xsl:text>&lt;/p&gt;</xsl:text>

                <xsl:apply-templates mode="html"/>

            </xsl:when>
            <xsl:otherwise>

                <xsl:text>&lt;p&gt;</xsl:text>
                <xsl:text>&lt;b&gt;Decoration:&lt;/b&gt; </xsl:text>
                <xsl:apply-templates mode="html"/>
                <xsl:text>&lt;/p&gt;</xsl:text>

            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <!--FILIATION-->
    <xsl:template name="get-item-filiation">

        <xsl:if test="*:filiation">
            <filiations>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="filiation">
                    <xsl:text>&lt;div&gt;</xsl:text>
                    <xsl:apply-templates select="*:filiation" mode="html"/>
                    <xsl:text>&lt;/div&gt;</xsl:text>
                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($filiation)"/>
                <!-- <xsl:value-of select="normalize-space($filiation)" /> -->
                <xsl:value-of select="normalize-space(replace($filiation, '&lt;[^&gt;]+&gt;', ''))"/>
            </filiations>
        </xsl:if>

    </xsl:template>

    <xsl:template match="*:filiation" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <!--************************************BIBLIOGRAPHY PROCESSING-->
    <xsl:template name="get-doc-biblio">

        <xsl:if test="//*:sourceDesc/*:msDesc/*:additional//*:listBibl">

            <bibliographies>

                <xsl:attribute name="display" select="'true'"/>

                <bibliography>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="bibliography">
                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:additional//*:listBibl"
                                             mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($bibliography)"/>
                    <!-- <xsl:value-of select="normalize-space($bibliography)" /> -->
                    <xsl:value-of
                        select="normalize-space(replace($bibliography, '&lt;[^&gt;]+&gt;', ''))"/>

                </bibliography>

            </bibliographies>

        </xsl:if>

    </xsl:template>


    <xsl:template name="get-doc-and-item-biblio">

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:additional//*:listBibl|//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:listBibl">

            <bibliographies>

                <xsl:attribute name="display" select="'true'"/>

                <bibliography>

                    <xsl:attribute name="display" select="'true'"/>

                    <xsl:variable name="bibliography">
                        <xsl:apply-templates
                            select="//*:sourceDesc/*:msDesc/*:additional//*:listBibl|//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:listBibl"
                            mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($bibliography)"/>
                    <!-- <xsl:value-of select="normalize-space($bibliography)" /> -->
                    <xsl:value-of
                        select="normalize-space(replace($bibliography, '&lt;[^&gt;]+&gt;', ''))"/>

                </bibliography>

            </bibliographies>

        </xsl:if>

    </xsl:template>


    <xsl:template name="get-item-biblio">

        <xsl:if test="*:listBibl">

            <!--         <bibliographies> -->
            <bibliographies>

                <xsl:attribute name="display" select="'true'"/>

                <bibliography>

                    <xsl:attribute name="display" select="'true'"/>
                    <xsl:variable name="bibliography">
                        <xsl:apply-templates select="*:listBibl" mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="displayForm" select="normalize-space($bibliography)"/>
                    <!-- <xsl:value-of select="normalize-space($bibliography)" /> -->
                    <xsl:value-of
                        select="normalize-space(replace($bibliography, '&lt;[^&gt;]+&gt;', ''))"/>

                </bibliography>

            </bibliographies>

        </xsl:if>

    </xsl:template>

    <xsl:template match="*:head" mode="html">

        <!-- <xsl:text>&lt;br /&gt;</xsl:text> -->

        <xsl:text>&lt;p&gt;&lt;b&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/b&gt;&lt;/p&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:listBibl" mode="html">


        <xsl:apply-templates select="*:head" mode="html"/>

        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
        <xsl:apply-templates select=".//*:bibl|.//*:biblStruct" mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

        <xsl:text>&lt;br /&gt;</xsl:text>

    </xsl:template>


    <xsl:template match="*:listBibl//*:bibl" mode="html">

        <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>


    <xsl:template match="*:listBibl//*:biblStruct[not(*)]" mode="html">

        <!-- Template to catch biblStruct w no child elements and treat like bibl - shouldn't really happen but frequently does, so prob easiest to handle it -->

        <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>


    <xsl:template match="*:listBibl//*:biblStruct[*:analytic]" mode="html">

        <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;</xsl:text>

        <xsl:choose>
            <xsl:when test="@xml:id">
                <xsl:text> id=&quot;</xsl:text>
                <xsl:value-of select="normalize-space(@xml:id)"/>
                <xsl:text>&quot;</xsl:text>
            </xsl:when>
            <xsl:when test="*:idno[@type='callNumber']">
                <xsl:text> id=&quot;</xsl:text>
                <xsl:value-of select="normalize-space(*:idno)"/>
                <xsl:text>&quot;</xsl:text>
            </xsl:when>
        </xsl:choose>

        <xsl:text>&gt;</xsl:text>

        <xsl:choose>
            <xsl:when
                test="@type='bookSection' or @type='encyclopaediaArticle' or @type='encyclopediaArticle'">

                <xsl:for-each select="*:analytic">

                    <xsl:for-each select="*:author|*:editor">

                        <xsl:call-template name="get-names-first-surname-first"/>

                    </xsl:for-each>

                    <xsl:text>, </xsl:text>

                    <xsl:for-each select="*:title">

                        <xsl:text>&quot;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&quot;</xsl:text>

                    </xsl:for-each>

                </xsl:for-each>

                <xsl:text>, in </xsl:text>

                <xsl:for-each select="*:monogr">

                    <xsl:choose>
                        <xsl:when test="*:author">

                            <xsl:for-each select="*:author">

                                <xsl:call-template name="get-names-all-forename-first"/>

                            </xsl:for-each>

                            <xsl:text>, </xsl:text>

                            <xsl:for-each select="*:title[not (@type='short')]">

                                <xsl:text>&lt;i&gt;</xsl:text>
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:text>&lt;/i&gt;</xsl:text>

                            </xsl:for-each>

                            <xsl:if test="*:editor">

                                <xsl:text>, ed. </xsl:text>

                                <xsl:for-each select="*:editor">

                                    <xsl:call-template name="get-names-all-forename-first"/>

                                </xsl:for-each>

                            </xsl:if>

                        </xsl:when>

                        <xsl:when test="*:editor">

                            <xsl:for-each select="*:editor">

                                <xsl:call-template name="get-names-all-forename-first"/>

                            </xsl:for-each>


                            <xsl:choose>
                                <xsl:when test="(count(*:editor) &gt; 1)">
                                    <xsl:text> (eds)</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text> (ed.)</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>

                            <xsl:text>, </xsl:text>

                            <xsl:for-each select="*:title[not(@type='short')]">

                                <xsl:text>&lt;i&gt;</xsl:text>
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:text>&lt;/i&gt;</xsl:text>

                            </xsl:for-each>

                        </xsl:when>

                        <xsl:otherwise>

                            <xsl:for-each select="*:title[not(@type='short')]">

                                <xsl:text>&lt;i&gt;</xsl:text>
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:text>&lt;/i&gt;</xsl:text>

                            </xsl:for-each>

                        </xsl:otherwise>

                    </xsl:choose>

                    <xsl:if test="*:edition">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="*:edition"/>
                    </xsl:if>

                    <xsl:if test="*:respStmt">

                        <xsl:for-each select="*:respStmt">

                            <xsl:text> </xsl:text>

                            <xsl:call-template name="get-respStmt"/>

                        </xsl:for-each>

                    </xsl:if>



                    <xsl:if test="../*:series">

                        <xsl:for-each select="../*:series">

                            <xsl:text>, </xsl:text>

                            <xsl:for-each select="*:title">

                                <!-- <xsl:text>&lt;i&gt;</xsl:text> -->
                                <xsl:value-of select="normalize-space(.)"/>
                                <!-- <xsl:text>&lt;/i&gt;</xsl:text> -->

                            </xsl:for-each>

                            <xsl:if test=".//*:biblScope">

                                <xsl:for-each select=".//*:biblScope">

                                    <xsl:text> </xsl:text>

                                    <xsl:if test="@type">
                                        <xsl:value-of select="normalize-space(@type)"/>
                                        <xsl:text>. </xsl:text>
                                    </xsl:if>

                                    <xsl:value-of select="normalize-space(.)"/>

                                </xsl:for-each>

                            </xsl:if>

                        </xsl:for-each>

                    </xsl:if>

                    <xsl:if test="*:imprint">

                        <xsl:text> </xsl:text>

                        <xsl:for-each select="*:imprint">

                            <xsl:call-template name="get-imprint"/>

                        </xsl:for-each>

                    </xsl:if>


                    <xsl:if test=".//*:biblScope">

                        <xsl:for-each select=".//*:biblScope">

                            <xsl:text> </xsl:text>

                            <xsl:if test="@type">
                                <xsl:value-of select="normalize-space(@type)"/>
                                <xsl:text>. </xsl:text>
                            </xsl:if>

                            <xsl:value-of select="normalize-space(.)"/>

                        </xsl:for-each>

                    </xsl:if>

                </xsl:for-each>

                <xsl:text>.</xsl:text>

            </xsl:when>

            <xsl:when test="@type='journalArticle'">

                <xsl:for-each select="*:analytic">

                    <xsl:for-each select="*:author|*:editor">

                        <xsl:call-template name="get-names-first-surname-first"/>

                    </xsl:for-each>

                    <xsl:text>, </xsl:text>

                    <xsl:for-each select="*:title">

                        <xsl:text>&quot;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&quot;</xsl:text>

                    </xsl:for-each>

                </xsl:for-each>

                <xsl:text>, </xsl:text>

                <xsl:for-each select="*:monogr">

                    <xsl:for-each select="*:title[not(@type='short')]">

                        <xsl:text>&lt;i&gt;</xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>
                        <xsl:text>&lt;/i&gt;</xsl:text>

                    </xsl:for-each>

                    <xsl:if test=".//*:biblScope">

                        <xsl:for-each select=".//*:biblScope">

                            <xsl:text> </xsl:text>

                            <xsl:if test="@type">
                                <xsl:value-of select="normalize-space(@type)"/>
                                <xsl:text>. </xsl:text>
                            </xsl:if>

                            <xsl:value-of select="normalize-space(.)"/>

                        </xsl:for-each>

                    </xsl:if>

                    <xsl:if test="../*:series">

                        <xsl:for-each select="../*:series">

                            <xsl:text>, </xsl:text>

                            <xsl:for-each select="*:title">

                                <!-- <xsl:text>&lt;i&gt;</xsl:text> -->
                                <xsl:value-of select="normalize-space(.)"/>
                                <!-- <xsl:text>&lt;/i&gt;</xsl:text> -->

                            </xsl:for-each>

                            <xsl:if test=".//*:biblScope">

                                <xsl:for-each select=".//*:biblScope">

                                    <xsl:text>. </xsl:text>

                                    <xsl:if test="@type">
                                        <xsl:value-of select="normalize-space(@type)"/>
                                        <xsl:text> </xsl:text>
                                    </xsl:if>

                                    <xsl:value-of select="normalize-space(.)"/>

                                </xsl:for-each>

                            </xsl:if>

                        </xsl:for-each>

                    </xsl:if>

                    <xsl:if test="*:imprint">

                        <xsl:text> </xsl:text>

                        <xsl:for-each select="*:imprint">

                            <xsl:call-template name="get-imprint"/>

                        </xsl:for-each>

                    </xsl:if>

                </xsl:for-each>

                <xsl:text>.</xsl:text>

            </xsl:when>

            <xsl:otherwise> </xsl:otherwise>

        </xsl:choose>

        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>



    <xsl:template match="*:listBibl//*:biblStruct[*:monogr and not(*:analytic)]" mode="html">

        <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;</xsl:text>

        <xsl:choose>
            <xsl:when test="@xml:id">
                <xsl:text> id=&quot;</xsl:text>
                <xsl:value-of select="normalize-space(@xml:id)"/>
                <xsl:text>&quot;</xsl:text>
            </xsl:when>
            <xsl:when test="*:idno[@type='callNumber']">
                <xsl:text> id=&quot;</xsl:text>
                <xsl:value-of select="normalize-space(*:idno)"/>
                <xsl:text>&quot;</xsl:text>
            </xsl:when>
        </xsl:choose>

        <xsl:text>&gt;</xsl:text>

        <xsl:choose>
            <xsl:when
                test="@type='book' or @type='document' or @type='thesis' or @type='manuscript' or @type='webpage'">

                <xsl:for-each select="*:monogr">

                    <xsl:choose>
                        <xsl:when test="*:author">

                            <xsl:for-each select="*:author">

                                <xsl:call-template name="get-names-first-surname-first"/>

                            </xsl:for-each>

                            <xsl:text>, </xsl:text>

                            <xsl:for-each select="*:title[not(@type='short')]">

                                <xsl:text>&lt;i&gt;</xsl:text>
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:text>&lt;/i&gt;</xsl:text>

                            </xsl:for-each>

                            <xsl:if test="*:editor">

                                <xsl:text>, ed. </xsl:text>

                                <xsl:for-each select="*:editor">

                                    <xsl:call-template name="get-names-all-forename-first"/>

                                </xsl:for-each>

                            </xsl:if>

                        </xsl:when>

                        <xsl:when test="*:editor">

                            <xsl:for-each select="*:editor">

                                <xsl:call-template name="get-names-first-surname-first"/>

                            </xsl:for-each>


                            <xsl:choose>
                                <xsl:when test="(count(*:editor) &gt; 1)">
                                    <xsl:text> (eds)</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text> (ed.)</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>

                            <xsl:text>, </xsl:text>

                            <xsl:for-each select="*:title[not(@type='short')]">

                                <xsl:text>&lt;i&gt;</xsl:text>
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:text>&lt;/i&gt;</xsl:text>

                            </xsl:for-each>

                        </xsl:when>

                        <xsl:otherwise>

                            <xsl:for-each select="*:title[not(@type='short')]">

                                <xsl:text>&lt;i&gt;</xsl:text>
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:text>&lt;/i&gt;</xsl:text>

                            </xsl:for-each>

                        </xsl:otherwise>

                    </xsl:choose>

                    <xsl:if test="*:edition">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="*:edition"/>
                    </xsl:if>

                    <xsl:if test="*:respStmt">

                        <xsl:for-each select="*:respStmt">

                            <xsl:text> </xsl:text>

                            <xsl:call-template name="get-respStmt"/>

                        </xsl:for-each>

                    </xsl:if>



                    <xsl:if test="../*:series">

                        <xsl:for-each select="../*:series">

                            <xsl:text>, </xsl:text>

                            <xsl:for-each select="*:title">

                                <!-- <xsl:text>&lt;i&gt;</xsl:text> -->
                                <xsl:value-of select="normalize-space(.)"/>
                                <!-- <xsl:text>&lt;/i&gt;</xsl:text> -->

                            </xsl:for-each>

                            <xsl:if test=".//*:biblScope">

                                <xsl:for-each select=".//*:biblScope">


                                    <xsl:text> </xsl:text>

                                    <xsl:if test="@type">
                                        <xsl:value-of select="normalize-space(@type)"/>
                                        <xsl:text>. </xsl:text>
                                    </xsl:if>

                                    <xsl:value-of select="normalize-space(.)"/>

                                </xsl:for-each>

                            </xsl:if>

                        </xsl:for-each>

                    </xsl:if>

                    <xsl:if test="*:extent">

                        <xsl:for-each select="*:extent">

                            <xsl:text>, </xsl:text>

                            <xsl:value-of select="normalize-space(.)"/>

                        </xsl:for-each>

                    </xsl:if>


                    <xsl:if test="*:imprint">

                        <xsl:for-each select="*:imprint">

                            <xsl:text> </xsl:text>

                            <xsl:call-template name="get-imprint"/>

                        </xsl:for-each>

                    </xsl:if>


                    <xsl:if test=".//*:biblScope">

                        <xsl:for-each select=".//*:biblScope">

                            <xsl:text> </xsl:text>

                            <xsl:if test="@type">
                                <xsl:value-of select="normalize-space(@type)"/>
                                <xsl:text>. </xsl:text>
                            </xsl:if>

                            <xsl:value-of select="normalize-space(.)"/>

                        </xsl:for-each>

                    </xsl:if>



                </xsl:for-each>

                <xsl:if test="*:idno[@type='ISBN']">

                    <xsl:for-each select="*:idno[@type='ISBN']">

                        <xsl:text> ISBN: </xsl:text>
                        <xsl:value-of select="normalize-space(.)"/>

                    </xsl:for-each>

                </xsl:if>



                <xsl:text>.</xsl:text>

            </xsl:when>

            <xsl:otherwise> </xsl:otherwise>
        </xsl:choose>


        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>


    <!--names processing for bibliography-->
    <xsl:template name="get-names-first-surname-first">

        <xsl:choose>
            <xsl:when test="position() = 1">
                <!-- first author = surname first -->

                <xsl:choose>
                    <xsl:when test=".//*:surname">
                        <!-- surname explicitly present -->

                        <xsl:for-each select=".//*:surname">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>

                        <xsl:if test=".//*:forename">
                            <xsl:text>, </xsl:text>

                            <xsl:for-each select=".//*:forename">
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:if test="not(position()=last())">
                                    <xsl:text> </xsl:text>
                                </xsl:if>
                            </xsl:for-each>

                        </xsl:if>

                    </xsl:when>
                    <xsl:when test="*:name[not(*)]">
                        <!-- just a name, not surname/forename -->

                        <xsl:for-each select=".//*:name[not(*)]">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>

                    </xsl:when>

                    <xsl:otherwise>
                        <!-- forenames only? not sure what else to do but render them -->

                        <xsl:for-each select=".//*:forename">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>

                    </xsl:otherwise>
                </xsl:choose>

            </xsl:when>
            <xsl:otherwise>
                <!-- not first author = forenames first -->

                <xsl:choose>
                    <xsl:when test="position()=last()">
                        <xsl:text> and </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>, </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>

                <xsl:choose>
                    <xsl:when test=".//*:surname">
                        <!-- surname explicitly present -->

                        <xsl:if test=".//*:forename">

                            <xsl:for-each select=".//*:forename">
                                <xsl:value-of select="normalize-space(.)"/>
                                <xsl:if test="not(position()=last())">
                                    <xsl:text> </xsl:text>
                                </xsl:if>
                            </xsl:for-each>

                            <xsl:text> </xsl:text>

                        </xsl:if>

                        <xsl:for-each select=".//*:surname">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>

                    </xsl:when>
                    <xsl:when test="*:name[not(*)]">
                        <!-- just a name, not forename/surname -->

                        <xsl:for-each select=".//*:name[not(*)]">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>

                    </xsl:when>
                    <xsl:otherwise>
                        <!-- forenames only? not sure what else to do but render them -->

                        <xsl:for-each select=".//*:forename">
                            <xsl:value-of select="normalize-space(.)"/>
                            <xsl:if test="not(position()=last())">
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>

                    </xsl:otherwise>

                </xsl:choose>

            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template name="get-names-all-forename-first">

        <xsl:choose>
            <xsl:when test="position() = 1"/>
            <xsl:when test="position()=last()">
                <xsl:text> and </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>, </xsl:text>
            </xsl:otherwise>
        </xsl:choose>

        <xsl:for-each select=".//*:name[not(*)]">
            <xsl:value-of select="normalize-space(.)"/>
            <xsl:if test="not(position()=last())">
                <xsl:text> </xsl:text>
            </xsl:if>
        </xsl:for-each>

        <xsl:for-each select=".//*:forename">
            <xsl:value-of select="normalize-space(.)"/>
            <xsl:if test="not(position()=last())">
                <xsl:text> </xsl:text>
            </xsl:if>
        </xsl:for-each>

        <xsl:text> </xsl:text>

        <xsl:for-each select=".//*:surname">
            <xsl:value-of select="normalize-space(.)"/>
            <xsl:if test="not(position()=last())">
                <xsl:text> </xsl:text>
            </xsl:if>
        </xsl:for-each>

    </xsl:template>

    <xsl:template name="get-imprint">


        <xsl:variable name="pubText">

            <xsl:if test="*:note[@type='thesisType']">
                <xsl:for-each select="*:note[@type='thesisType']">
                    <xsl:value-of select="normalize-space(.)"/>
                    <xsl:text> thesis</xsl:text>
                </xsl:for-each>
                <xsl:text> </xsl:text>
            </xsl:if>

            <xsl:if test="*:pubPlace">
                <xsl:for-each select="*:pubPlace">
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:for-each>
                <xsl:text>: </xsl:text>
            </xsl:if>

            <xsl:if test="*:publisher">
                <xsl:for-each select="*:publisher">
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:for-each>
                <xsl:if test="*:date">
                    <xsl:text>, </xsl:text>
                </xsl:if>
            </xsl:if>

            <xsl:if test="*:date">
                <xsl:for-each select="*:date">
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:for-each>
            </xsl:if>




        </xsl:variable>


        <xsl:if test="normalize-space($pubText)">

            <xsl:text>(</xsl:text>
            <xsl:value-of select="$pubText"/>
            <xsl:text>)</xsl:text>

        </xsl:if>



        <xsl:if test="*:note[@type='url']">
            <xsl:text> &lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
            <xsl:value-of select="*:note[@type='url']"/>
            <xsl:text>&apos;&gt;</xsl:text>
            <xsl:value-of select="*:note[@type='url']"/>
            <xsl:text>&lt;/a&gt;</xsl:text>
        </xsl:if>

        <xsl:if test="*:note[@type='accessed']">
            <xsl:text> Accessed: </xsl:text>
            <xsl:for-each select="*:note[@type='accessed']">
                <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
        </xsl:if>

    </xsl:template>

    <xsl:template name="get-respStmt">

        <xsl:choose>
            <xsl:when test="*">
                <xsl:for-each select="*:resp">
                    <xsl:value-of select="."/>
                    <xsl:text>: </xsl:text>
                </xsl:for-each>
                <xsl:for-each select=".//*:forename">
                    <xsl:value-of select="."/>
                    <xsl:text> </xsl:text>
                </xsl:for-each>
                <xsl:for-each select=".//*:surname">
                    <xsl:value-of select="."/>
                    <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                    </xsl:if>
                </xsl:for-each>
                <xsl:for-each select=".//*:name[not(*)]">
                    <xsl:value-of select="."/>
                    <xsl:if test="not(position()=last())">
                        <xsl:text> </xsl:text>
                    </xsl:if>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="."/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>


    <!--*******************************************NAMES-->

    <!-- Table of role relator codes and role element names -->
    <xsl:variable name="rolemap">
        <role code="aut" name="authors"/>
        <role code="dnr" name="donors"/>
        <role code="fmo" name="formerOwners"/>
        <!-- Treat pbl as "associated"
         <role code="pbl" name="publishers" />
      -->
        <role code="rcp" name="recipients"/>
        <role code="scr" name="scribes"/>
    </xsl:variable>

    <xsl:template name="get-doc-names">

        <!--for doc names looks only in summary, physdesc and history-->

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]">

            <xsl:for-each-group
                select="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]"
                group-by="@role">

                <xsl:variable name="rolecode" select="@role"/>

                <xsl:variable name="elementName" select="$rolemap/role[@code=$rolecode]/@name"/>
                <!--
            <xsl:variable name="label" select="$rolemap/role[@code=$rolecode]/@label" />
            -->


                <xsl:element name="{$elementName}">
                    <xsl:attribute name="display" select="'true'"/>



                    <!-- to de-dup names, group by name and process just first one in group -->
                    <xsl:for-each-group select="current-group()" group-by="*:persName[@type='standard']">

                        <!-- <xsl:sort select="*:persName[@type='standard']" /> -->
                        <!-- CHECK WHETHER ORDER SIGNIFICANT -->

                        <xsl:choose>
                            <xsl:when test="normalize-space(*:persName[@type='standard'])">
                                <xsl:apply-templates select="current-group()[1]"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- if no standard name then may be several names grouped together -->
                                <xsl:for-each-group select="current-group()" group-by="*:persName">
                                    <xsl:apply-templates select="current-group()[1]"/>
                                </xsl:for-each-group>
                            </xsl:otherwise>
                        </xsl:choose>

                    </xsl:for-each-group>

                </xsl:element>

            </xsl:for-each-group>

            <xsl:if
                test="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]">

                <associated>

                    <xsl:attribute name="display" select="'true'"/>


                    <xsl:for-each-group
                        select="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]"
                        group-by="*:persName[@type='standard']">

                        <xsl:sort select="*:persName[@type='standard']"/>

                        <xsl:choose>
                            <xsl:when test="normalize-space(*:persName[@type='standard'])">
                                <xsl:apply-templates select="current-group()[1]"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- if no standard name then may be several names grouped together -->
                                <xsl:for-each-group select="current-group()" group-by="*:persName">
                                    <xsl:apply-templates select="current-group()[1]"/>
                                </xsl:for-each-group>
                            </xsl:otherwise>
                        </xsl:choose>

                    </xsl:for-each-group>

                </associated>

            </xsl:if>

        </xsl:if>

        <!--special case where listPerson element has been used to group together all names-->

        <xsl:if test="//*:sourceDesc/*:listPerson">



            <associated>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:apply-templates select="//*:sourceDesc/*:listPerson/*:person/*:persName"
                                     mode="listperson"/>

            </associated>

        </xsl:if>

    </xsl:template>

    <xsl:template name="get-doc-and-item-names">


        <!--for doc and item, looks in summary, physdesc, history, first msItem author and respstmt fields-->
        <!--simplify to just pick up all names in first msItem?-->

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]|//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:author/*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]
         |//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:respStmt/*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]">

            <xsl:for-each-group
                select="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]|//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:author/*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]
|//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:respStmt/*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][@role=$rolemap/role/@code]"
                group-by="@role">

                <xsl:variable name="rolecode" select="@role"/>

                <xsl:variable name="elementName" select="$rolemap/role[@code=$rolecode]/@name"/>
                <!--
            <xsl:variable name="label" select="$rolemap/role[@code=$rolecode]/@label" />
            -->

                <xsl:element name="{$elementName}">
                    <xsl:attribute name="display" select="'true'"/>


                    <!-- to de-dup names, group by name and process just first one in group -->
                    <xsl:for-each-group select="current-group()" group-by="*:persName[@type='standard']">

                        <!-- <xsl:sort select="*:persName[@type='standard']" /> -->
                        <!-- CHECK WHETHER ORDER SIGNIFICANT -->
                        <xsl:choose>
                            <xsl:when test="normalize-space(*:persName[@type='standard'])">
                                <xsl:apply-templates select="current-group()[1]"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- if no standard name then may be several names grouped together -->
                                <xsl:for-each-group select="current-group()" group-by="*:persName">
                                    <xsl:apply-templates select="current-group()[1]"/>
                                </xsl:for-each-group>
                            </xsl:otherwise>
                        </xsl:choose>

                    </xsl:for-each-group>

                </xsl:element>

            </xsl:for-each-group>
        </xsl:if>

        <xsl:if
            test="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]
            |//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:respStmt/*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)][not(@role='pbl')]">

            <associated>

                <xsl:attribute name="display" select="'true'"/>
                <!--
               <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(@role=$rolemap/role/@code)]"/>
               -->
                <xsl:for-each-group
                    select="//*:sourceDesc/*:msDesc/*:msContents/*:summary//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:physDesc//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]|//*:sourceDesc/*:msDesc/*:history//*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)]
                  |//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:respStmt/*:name[*:persName][not(contains(lower-case(*:persName[@type='standard']), 'unknown'))][not(@role=$rolemap/role/@code)][not(@role='pbl')]"
                    group-by="*:persName[@type='standard']">

                    <xsl:sort select="*:persName[@type='standard']"/>

                    <xsl:choose>
                        <xsl:when test="normalize-space(*:persName[@type='standard'])">
                            <xsl:apply-templates select="current-group()[1]"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <!-- if no standard name then may be several names grouped together -->
                            <xsl:for-each-group select="current-group()" group-by="*:persName">
                                <xsl:apply-templates select="current-group()[1]"/>
                            </xsl:for-each-group>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:for-each-group>

            </associated>

        </xsl:if>

        <!--special case where listPerson element has been used to group together all names-->

        <xsl:if test="//*:sourceDesc/*:listPerson">

            <associated>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:apply-templates select="//*:sourceDesc/*:listPerson/*:person/*:persName"
                                     mode="listperson"/>

            </associated>

        </xsl:if>

    </xsl:template>

    <xsl:template name="get-item-names">

        <!--for items, just look in author field-->
        <!--look for all names in msItem?-->

        <xsl:if
            test="*:author/*:name[not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]">

            <authors>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:apply-templates
                    select="*:author/*:name[not(contains(lower-case(*:persName[@type='standard']), 'unknown'))]"/>

            </authors>

        </xsl:if>

    </xsl:template>

    <xsl:template match="*:name[*:persName]">

        <name>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:choose>
                <xsl:when test="*:persName[@type='standard']">
                    <xsl:for-each select="*:persName[@type='standard']">
                        <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                        <fullForm>
                            <xsl:value-of select="normalize-space(.)"/>
                        </fullForm>
                    </xsl:for-each>

                    <xsl:choose>
                        <!-- if separate display form exists, use as short form -->
                        <xsl:when test="*:persName[@type='display']">
                            <xsl:for-each select="*:persName[@type='display']">
                                <shortForm>
                                    <xsl:value-of select="normalize-space(.)"/>
                                </shortForm>
                            </xsl:for-each>

                        </xsl:when>
                        <!-- if no separate display form exists, use standard form as short form -->
                        <xsl:otherwise>
                            <xsl:for-each select="*:persName[@type='standard']">
                                <shortForm>
                                    <xsl:value-of select="normalize-space(.)"/>
                                </shortForm>
                            </xsl:for-each>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:when>
                <xsl:when test="*:persName[@type='display']">
                    <xsl:for-each select="*:persName[@type='display']">
                        <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                        <shortForm>
                            <xsl:value-of select="normalize-space(.)"/>
                        </shortForm>
                    </xsl:for-each>

                </xsl:when>
                <xsl:otherwise>
                    <!-- No standard form, no display form, take whatever we've got? -->
                    <xsl:for-each select="*:persName">
                        <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                        <shortForm>
                            <xsl:value-of select="normalize-space(.)"/>
                        </shortForm>
                    </xsl:for-each>

                </xsl:otherwise>
            </xsl:choose>


            <xsl:for-each select="@type">
                <type>
                    <xsl:value-of select="normalize-space(.)"/>
                </type>
            </xsl:for-each>

            <xsl:for-each select="@role">
                <role>
                    <xsl:value-of select="normalize-space(.)"/>
                </role>
            </xsl:for-each>

            <xsl:for-each select="@key[contains(., 'VIAF_')]">

                <authority>VIAF</authority>
                <authorityURI>http://viaf.org/</authorityURI>

                <!-- Possible that there are multiple VIAF_* tokens (if multiple VIAF entries for same person) e.g. Sanskrit MS-OR-02339. For now, just use first, but should maybe handle multiple -->
                <xsl:for-each select="tokenize(normalize-space(.), ' ')[starts-with(., 'VIAF_')][1]">

                    <!-- <xsl:if test="starts-with(., 'VIAF_')"> -->
                    <valueURI>
                        <xsl:value-of select="concat('http://viaf.org/viaf/', substring-after(.,'VIAF_'))"
                        />
                    </valueURI>
                    <!-- </xsl:if> -->
                </xsl:for-each>

            </xsl:for-each>

        </name>

    </xsl:template>


    <xsl:template match="*:person/*:persName" mode="listperson">

        <name>

            <xsl:attribute name="display" select="'true'"/>

            <xsl:attribute name="displayForm" select="normalize-space(.)"/>

            <fullForm>
                <xsl:value-of select="normalize-space(.)"/>
            </fullForm>

            <type>
                <xsl:text>person</xsl:text>
            </type>

            <role>
                <xsl:text>oth</xsl:text>
            </role>

        </name>

    </xsl:template>




    <xsl:template name="get-part-names">
        <!-- TODO -->
    </xsl:template>

    <xsl:template name="get-part-languages">
        <!-- TODO -->
    </xsl:template>



    <!--******************************LANGUAGES-->
    <xsl:template name="get-doc-languages">

        <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:textLang/@mainLang">

            <languageCodes>

                <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msContents/*:textLang/@mainLang">

                    <languageCode>
                        <xsl:value-of select="normalize-space(.)"/>
                    </languageCode>

                </xsl:for-each>

            </languageCodes>

        </xsl:if>

        <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:textLang">

            <languageStrings>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="//*:sourceDesc/*:msDesc/*:msContents/*:textLang">

                    <languageString>

                        <xsl:attribute name="display" select="'true'"/>
                        <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                        <xsl:value-of select="normalize-space(.)"/>
                    </languageString>

                </xsl:for-each>

            </languageStrings>

        </xsl:if>

    </xsl:template>



    <xsl:template name="get-item-languages">

        <xsl:if test="*:textLang/@mainLang">

            <languageCodes>

                <xsl:for-each select="*:textLang/@mainLang">

                    <languageCode>
                        <xsl:value-of select="normalize-space(.)"/>
                    </languageCode>

                </xsl:for-each>

            </languageCodes>

        </xsl:if>

        <xsl:if test="*:textLang">

            <languageStrings>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:for-each select="*:textLang">

                    <languageString>

                        <xsl:attribute name="display" select="'true'"/>
                        <xsl:attribute name="displayForm" select="normalize-space(.)"/>
                        <xsl:value-of select="normalize-space(.)"/>
                    </languageString>

                </xsl:for-each>

            </languageStrings>

        </xsl:if>

    </xsl:template>


    <!--******************************DATA SOURCES AND REVISIONS-->
    <xsl:template name="get-doc-metadata">

        <xsl:if
            test="normalize-space(//*:sourceDesc/*:msDesc/*:additional/*:adminInfo/*:recordHist/*:source)">

            <dataSources>

                <xsl:attribute name="display" select="'true'"/>

                <dataSource>

                    <xsl:variable name="dataSource">
                        <xsl:apply-templates
                            select="//*:sourceDesc/*:msDesc/*:additional/*:adminInfo/*:recordHist/*:source"
                            mode="html"/>
                    </xsl:variable>

                    <xsl:attribute name="display" select="'true'"/>
                    <xsl:attribute name="displayForm" select="normalize-space($dataSource)"/>
                    <!-- <xsl:value-of select="normalize-space($dataSource)" /> -->
                    <xsl:value-of select="normalize-space(replace($dataSource, '&lt;[^&gt;]+&gt;', ''))"/>

                </dataSource>

            </dataSources>

        </xsl:if>

        <xsl:if test="normalize-space(//*:revisionDesc)">

            <dataRevisions>

                <xsl:attribute name="display" select="'true'"/>

                <xsl:variable name="dataRevisions">
                    <!--<xsl:apply-templates select="//*:revisionDesc/*:change[1]/*:persName" mode="html" />-->

                    <xsl:value-of select="distinct-values(//*:revisionDesc/*:change/*:persName)"
                                  separator=", "/>

                </xsl:variable>

                <xsl:attribute name="displayForm" select="normalize-space($dataRevisions)"/>
                <!-- <xsl:value-of select="normalize-space($dataRevisions)" /> -->
                <xsl:value-of select="normalize-space(replace($dataRevisions, '&lt;[^&gt;]+&gt;', ''))"/>

            </dataRevisions>

        </xsl:if>

    </xsl:template>

    <xsl:template match="*:recordHist/*:source" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:revisionDesc" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:revisionDesc/*:change" mode="html">

        <xsl:apply-templates mode="html"/>

        <xsl:if test="not(position()=last())">
            <xsl:text>&lt;br /&gt;</xsl:text>
        </xsl:if>

    </xsl:template>



    <!--************************************COLLECTIONS-->
    <xsl:template name="get-CollectionJSON-memberships">
        <!-- Lookup collections of which this item is a member (from SQL database) -->

        <xsl:element name="collections">


            <xsl:for-each select="cudl:get-memberships($fileID)">

                <xsl:element name="CollectionJSON">
                    <xsl:value-of select="title"/>
                </xsl:element>
            </xsl:for-each>
        </xsl:element>

    </xsl:template>


    <!--FLAGS-->

    <!--*********************************** number of pages -->
    <xsl:template name="get-numberOfPages">
        <numberOfPages>
            <xsl:choose>
                <xsl:when test="//*:facsimile/*:surface">

                    <xsl:value-of select="count(//*:facsimile/*:surface)"/>

                </xsl:when>

                <xsl:otherwise>
                    <xsl:text>1</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </numberOfPages>
    </xsl:template>


    <!-- ********************************* embeddable -->
    <xsl:template name="get-embeddable">

        <xsl:variable name="downloadImageRights"
                      select="normalize-space(//*:publicationStmt/*:availability[@xml:id='downloadImageRights'])"/>
        <xsl:variable name="images"
                      select="normalize-space(//*:facsimile/*:surface[1]/*:graphic[1]/@url)"/>



        <embeddable>
            <xsl:choose>

                <xsl:when test="normalize-space($images)">

                    <xsl:text>true</xsl:text>


                    <!--<xsl:choose>
                  <xsl:when test="normalize-space($downloadImageRights)">true</xsl:when>
                  <xsl:otherwise>false</xsl:otherwise>
               </xsl:choose>
               -->

                </xsl:when>

                <xsl:otherwise>false</xsl:otherwise>
            </xsl:choose>
        </embeddable>

    </xsl:template>


    <!-- ********************************* text direction -->
    <xsl:template name="get-text-direction">


        <xsl:variable name="languageCode">

            <xsl:choose>
                <xsl:when test="//*:sourceDesc/*:msDesc/*:msContents/*:textLang/@mainLang">

                    <xsl:value-of select="//*:sourceDesc/*:msDesc/*:msContents/*:textLang/@mainLang"/>

                </xsl:when>


                <xsl:when
                    test="count(//*:sourceDesc/*:msDesc/*:msContents/*:msItem) = 1 and //*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:textLang/@mainLang">

                    <xsl:value-of
                        select="//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]/*:textLang/@mainLang"/>

                </xsl:when>

                <xsl:otherwise>

                    <xsl:text>none</xsl:text>

                </xsl:otherwise>


            </xsl:choose>


        </xsl:variable>


        <xsl:variable name="textDirection">
            <xsl:value-of select="cudl:get-language-direction($languageCode)"/>
        </xsl:variable>

        <!--<xsl:message>
         <xsl:text>For language </xsl:text>
         <xsl:value-of select="$languageCode"/>
         <xsl:text> text direction is </xsl:text>
         <xsl:value-of select="$textDirection"/>
      </xsl:message>-->

        <textDirection>
            <xsl:value-of select="$textDirection"/>
        </textDirection>


    </xsl:template>


    <!-- ****************************sourceData -->
    <!--path to source data for download - mainly hard coded-->
    <xsl:template name="get-sourceData">

        <sourceData>
            <xsl:value-of select="concat('/v1/metadata/tei/',$fileID,'/')"/>
        </sourceData>

    </xsl:template>

    <!--transcription flags-->
    <xsl:template name="get-transcription-flags">


        <!--rework this system of flags in favour of automatic tab creation at page level?-->
        <xsl:choose>
            <xsl:when test="//*:surface/*:media[contains(@mimeType,'transcription')]">
                <useTranscriptions>true</useTranscriptions>

                <xsl:if test="//*:surface/*:media[@mimeType='transcription_diplomatic']">

                    <useDiplomaticTranscriptions>true</useDiplomaticTranscriptions>

                </xsl:if>

                <xsl:if test="//*:surface/*:media[@mimeType='transcription_normalised']">

                    <useNormalisedTranscriptions>true</useNormalisedTranscriptions>

                </xsl:if>


            </xsl:when>

            <xsl:when test="//*:text/*:body/*:div[not(@type)]/*[not(local-name()='pb')]">

                <useTranscriptions>true</useTranscriptions>
                <useDiplomaticTranscriptions>true</useDiplomaticTranscriptions>

            </xsl:when>


        </xsl:choose>




        <xsl:if test="//*:text/*:body/*:div[@type='translation']/*[not(local-name()='pb')]">

            <useTranslations>true</useTranslations>

        </xsl:if>

    </xsl:template>


    <!--***********************************************************************STRUCTURE-->
    <!--*****************************make pages and urls which relate to them-->
    <xsl:template name="make-pages">

        <pages>

            <xsl:choose>

                <!--does the item have any images?-->
                <xsl:when test="//*:facsimile/*:surface">

                    <xsl:for-each select="//*:facsimile/*:surface">

                        <xsl:variable name="label" select="normalize-space(@n)"/>

                        <page>
                            <label>
                                <xsl:value-of select="$label"/>
                            </label>

                            <physID>
                                <xsl:value-of select="concat('PHYS-',position())"/>
                            </physID>

                            <sequence>
                                <xsl:value-of select="position()"/>
                            </sequence>

                            <xsl:variable name="imageUrl"
                                          select="normalize-space(*:graphic[contains(@decls, '#download')]/@url)"/>

                            <xsl:variable name="thumbnailOrientation"
                                          select="normalize-space(*:graphic[contains(@decls, '#download')]/@rend)"/>

                            <xsl:variable name="imageWidth1"
                                          select="normalize-space(*:graphic[contains(@decls, '#download')]/@width)"/>

                            <xsl:variable name="imageWidth" select="replace($imageWidth1, 'px', '')"/>

                            <xsl:variable name="imageHeight1"
                                          select="normalize-space(*:graphic[contains(@decls, '#download')]/@height)"/>

                            <xsl:variable name="imageHeight" select="replace($imageHeight1, 'px', '')"/>


                            <IIIFImageURL>

                                <xsl:value-of select="$imageUrl"/>

                            </IIIFImageURL>

                            <thumbnailImageOrientation>
                                <xsl:value-of select="$thumbnailOrientation"/>
                            </thumbnailImageOrientation>

                            <!--default values for testing-->
                            <imageWidth>
                                <xsl:choose>
                                    <xsl:when test="normalize-space($imageWidth)">
                                        <xsl:value-of select="$imageWidth"/>
                                    </xsl:when>
                                    <xsl:otherwise>0</xsl:otherwise>
                                </xsl:choose>

                            </imageWidth>
                            <imageHeight>
                                <xsl:choose>


                                    <xsl:when test="normalize-space($imageHeight)">
                                        <xsl:value-of select="$imageHeight"/>
                                    </xsl:when>
                                    <xsl:otherwise>0</xsl:otherwise>
                                </xsl:choose>
                            </imageHeight>


                            <xsl:if
                                test="normalize-space(*:media[@mimeType='transcription_diplomatic']/@url)">

                                <xsl:variable name="transDiplUrl"
                                              select="*:media[@mimeType='transcription_diplomatic']/@url"/>
                                <xsl:variable name="transDiplUrlShort"
                                              select="replace($transDiplUrl, 'http://services.cudl.lib.cam.ac.uk','')"/>

                                <transcriptionDiplomaticURL>
                                    <xsl:value-of select="normalize-space($transDiplUrlShort)"/>

                                </transcriptionDiplomaticURL>

                            </xsl:if>

                            <xsl:if
                                test="normalize-space(*:media[@mimeType='transcription_normalised']/@url)">

                                <xsl:variable name="transNormUrl"
                                              select="*:media[@mimeType='transcription_normalised']/@url"/>
                                <xsl:variable name="transNormUrlShort"
                                              select="replace($transNormUrl, 'http://services.cudl.lib.cam.ac.uk','')"/>

                                <transcriptionNormalisedURL>
                                    <xsl:value-of select="normalize-space($transNormUrlShort)"/>

                                </transcriptionNormalisedURL>

                            </xsl:if>


                            <xsl:variable name="isLast">
                                <xsl:choose>
                                    <xsl:when test="position()=last()">
                                        <xsl:text>true</xsl:text>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text>false</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>


                            </xsl:variable>

                            <!-- Page transcription -->
                            <xsl:choose>




                                <!--when file contains external transcription do nothing here-->
                                <xsl:when test="*:media[contains(@mimeType,'transcription')]"/>


                                <xsl:otherwise>

                                    <xsl:for-each select="//*:text/*:body/*:div[not(@type)]//*:pb[@n=$label]">




                                        <xsl:choose>
                                            <xsl:when test="$isLast='true' and count(following-sibling::*)=0"/>



                                            <!--when there's no content between here and the next pb element do nothing-->
                                            <xsl:when test="local-name(following-sibling::*[1])='pb'"/>


                                            <xsl:otherwise>
                                                <!-- transcription content present so set up page extract URI  -->




                                                <transcriptionDiplomaticURL>

                                                    <xsl:value-of select="concat('/v1/transcription/tei/diplomatic/internal/',$fileID,'/',$label,'/',$label)"/>

                                                </transcriptionDiplomaticURL>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:for-each>
                                </xsl:otherwise>

                            </xsl:choose>


                            <xsl:for-each select="//*:text/*:body/*:div[@type='translation']//*:pb[@n=$label]">



                                <!-- Page translation -->
                                <xsl:choose>
                                    <!--when this pb has no following siblings i.e. it is the last element pb element and is not followed by content, do nothing-->
                                    <!--<xsl:when test="count(following-sibling::*)=0" />-->
                                    <xsl:when test="$isLast='true' and count(following-sibling::*)=0"/>

                                    <!--when there's no content between here and the next pb element do nothing-->
                                    <xsl:when test="local-name(following-sibling::*[1])='pb'" >

                                    </xsl:when>
                                    <xsl:otherwise>
                                        <!-- translation content present so set up page extract URI  -->
                                        <translationURL>

                                            <xsl:value-of select="concat('/v1/translation/tei/EN/',$fileID,'/',$label,'/',$label)"/>


                                        </translationURL>

                                    </xsl:otherwise>
                                </xsl:choose>


                            </xsl:for-each>

                            <!--
                  Note: possible to have:
                  - page with neither image nor transcription
                  - page with image but no transcription
                  - page with transcription but no image
                  - page with image and transcription
               -->
                        </page>

                    </xsl:for-each>

                </xsl:when>


                <!--default single page for items without images-->
                <xsl:otherwise>

                    <page>
                        <label>
                            <xsl:text>cover</xsl:text>
                        </label>

                        <physID>
                            <xsl:text>PHYS-1</xsl:text>
                        </physID>

                        <sequence>
                            <xsl:text>1</xsl:text>
                        </sequence>
                    </page>

                </xsl:otherwise>


            </xsl:choose>

        </pages>

    </xsl:template>

    <!--LIST ITEM PAGES - passing through for indexing-->
    <xsl:template name="make-list-item-pages">


        <listItemPages>

            <!--this indexes any list items containing at least one locus element under the from attribute of the first locus-->
            <xsl:for-each select="//*:list/*:item[*:locus]">


                <listItemPage>
                    <xsl:attribute name="xtf:subDocument" select="concat('listItem-', position())" />


                    <fileID>
                        <xsl:value-of select="$fileID"/>
                    </fileID>

                    <!-- Below is a bit of a fudge. It uses the "top-level" dmdID in all cases. What it should really do is work out where this page is in the logical structure. But as CollectionJSON facet already propagated throughout, and subjects and dates(?) only at top level, can probably get away with it without losing out on fact inheritance -->

                    <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:msItem">
                        <xsl:choose>
                            <xsl:when test="count(//*:sourceDesc/*:msDesc/*:msContents/*:msItem) = 1">
                                <dmdID xtf:noindex="true">ITEM-1</dmdID>
                            </xsl:when>
                            <xsl:otherwise>
                                <dmdID xtf:noindex="true">DOCUMENT</dmdID>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>

                    <xsl:variable name="startPageLabel" select="*:locus[1]/@from"/>

                    <xsl:variable name="startPagePosition">

                        <xsl:choose>
                            <xsl:when test="//*:facsimile/*:surface">
                                <xsl:for-each select="//*:facsimile/*:surface" >
                                    <xsl:if test="@n = $startPageLabel">
                                        <xsl:value-of select="position()" />
                                    </xsl:if>
                                </xsl:for-each>
                                <!--<xsl:variable name="xmlid" select="//*:facsimile/*:surface[@n=$startPageLabel]/@xml:id"/>
                        <xsl:value-of select="substring-after($xmlid, 'i')"></xsl:value-of>-->
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>1</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>

                    </xsl:variable>


                    <startPageLabel>
                        <xsl:value-of select="$startPageLabel"/>



                    </startPageLabel>

                    <startPage>
                        <xsl:value-of select="$startPagePosition"/>
                    </startPage>

                    <title>
                        <xsl:value-of select="$startPageLabel"/>
                    </title>

                    <listItemText>

                        <xsl:value-of select="normalize-space(.)"/>


                    </listItemText>

                </listItemPage>

            </xsl:for-each>


        </listItemPages>

    </xsl:template>


    <!--make logical structure for navigation-->
    <xsl:template name="make-logical-structure">

        <logicalStructures xtf:noindex="true">

            <xsl:if test="//*:sourceDesc/*:msDesc/*:msContents/*:msItem">

                <xsl:choose>
                    <xsl:when test="count(//*:sourceDesc/*:msDesc/*:msContents/*:msItem) = 1">

                        <!-- Just one top-level item -->

                        <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:msContents/*:msItem[1]" mode="logicalstructure" />

                        <xsl:apply-templates select="//*:msDesc/*:msPart/*:msContents/*:msItem"
                                             mode="logicalstructure"/>

                    </xsl:when>
                    <xsl:otherwise>

                        <!-- Sequence of top-level items, so need to wrap -->

                        <logicalStructure>

                            <descriptiveMetadataID>
                                <xsl:value-of select="'DOCUMENT'"/>
                            </descriptiveMetadataID>

                            <label>
                                <xsl:choose>
                                    <xsl:when test="//*:sourceDesc/*:msDesc/*:msContents/*:summary/*:title[@type='general']">
                                        <xsl:value-of select="*:msDesc/*:msContents/*:summary/*:title[@type='general'][1]"/>
                                    </xsl:when>
                                    <xsl:when test="//*:sourceDesc/*:msDesc/*:head">
                                        <xsl:value-of select="normalize-space(//*:sourceDesc/*:msDesc/*:head)"/>
                                    </xsl:when>
                                    <xsl:when test="//*:sourceDesc/*:msDesc/*:msContents/*:summary/*:title">
                                        <xsl:value-of select="*:msDesc/*:msContents/*:summary/*:title[1]"/>
                                    </xsl:when>
                                    <xsl:when test="//*:sourceDesc/*:msDesc/*:msIdentifier/*:idno">
                                        <xsl:value-of select="normalize-space(//*:sourceDesc/*:msDesc/*:msIdentifier/*:idno)"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text>Untitled Document</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </label>

                            <startPageLabel>

                                <xsl:choose>
                                    <xsl:when test="//*:facsimile/*:surface">
                                        <xsl:value-of select="//*:facsimile/*:surface[1]/@n"/>

                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text>cover</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>


                            </startPageLabel>

                            <startPagePosition>
                                <xsl:text>1</xsl:text>
                            </startPagePosition>

                            <startPageID>
                                <xsl:value-of select="'PHYS-1'" />
                            </startPageID>

                            <endPageLabel>

                                <xsl:choose>
                                    <xsl:when test="//*:facsimile/*:surface">

                                        <xsl:value-of select="//*:facsimile/*:surface[last()]/@n"/>

                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text>cover</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>

                            </endPageLabel>

                            <endPagePosition>
                                <xsl:choose>
                                    <xsl:when test="//*:facsimile/*:surface">
                                        <xsl:value-of select="count(//*:facsimile/*:surface)"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text>1</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>

                            </endPagePosition>

                            <children>
                                <xsl:apply-templates select="//*:sourceDesc/*:msDesc/*:msContents/*:msItem" mode="logicalstructure" />
                            </children>
                        </logicalStructure>

                    </xsl:otherwise>
                </xsl:choose>

            </xsl:if>

        </logicalStructures>

    </xsl:template>


    <xsl:template match="*:msItem" mode="logicalstructure">

        <logicalStructure>

            <xsl:variable name="n-tree">
                <xsl:value-of select="sum((count(ancestor-or-self::*[local-name()='msItem' or local-name()='msPart']), count(preceding::*[local-name()='msItem' or local-name()='msPart'])))" />
            </xsl:variable>

            <descriptiveMetadataID>
                <xsl:value-of select="concat('ITEM-', normalize-space($n-tree))"/>
            </descriptiveMetadataID>

            <label>
                <xsl:choose>
                    <xsl:when test="normalize-space(*:title[not(@type)][1])">
                        <xsl:value-of select="normalize-space(*:title[not(@type)][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:title[@type='general'][1])">
                        <xsl:value-of select="normalize-space(*:title[@type='general'][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:title[@type='standard'][1])">
                        <xsl:value-of select="normalize-space(*:title[@type='standard'][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:title[@type='supplied'][1])">
                        <xsl:value-of select="normalize-space(*:title[@type='supplied'][1])"/>
                    </xsl:when>
                    <xsl:when test="normalize-space(*:rubric)">
                        <xsl:variable name="rubric_title">

                            <xsl:apply-templates select="*:rubric" mode="title"/>

                        </xsl:variable>

                        <xsl:value-of select="normalize-space($rubric_title)"/>
                    </xsl:when>

                    <xsl:when test="normalize-space(*:incipit)">
                        <xsl:variable name="incipit_title">

                            <xsl:apply-templates select="*:incipit" mode="title"/>

                        </xsl:variable>

                        <xsl:value-of select="normalize-space($incipit_title)"/>
                    </xsl:when>


                    <xsl:otherwise>
                        <xsl:text>Untitled Item</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </label>

            <xsl:variable name="startPageLabel">
                <xsl:choose>
                    <xsl:when test="*:locus/@from">
                        <xsl:value-of select="normalize-space(*:locus/@from)" />
                    </xsl:when>
                    <xsl:otherwise>

                        <xsl:choose>
                            <xsl:when test="//*:facsimile/*:surface">
                                <xsl:value-of select="//*:facsimile/*:surface[1]/@n"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>cover</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>

                    </xsl:otherwise>

                </xsl:choose>
            </xsl:variable>

            <startPageLabel>
                <xsl:value-of select="$startPageLabel" />

            </startPageLabel>

            <xsl:variable name="startPagePosition">


                <xsl:choose>
                    <xsl:when test="//*:facsimile/*:surface">
                        <xsl:for-each select="//*:facsimile/*:surface" >
                            <xsl:if test="@n = $startPageLabel">
                                <xsl:value-of select="position()" />
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>1</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>


            </xsl:variable>

            <startPagePosition>
                <xsl:value-of select="$startPagePosition" />
            </startPagePosition>

            <startPageID>
                <xsl:value-of select="concat('PHYS-',$startPagePosition)" />
            </startPageID>



            <xsl:variable name="endPageLabel">
                <xsl:choose>
                    <xsl:when test="*:locus/@to">
                        <xsl:value-of select="normalize-space(*:locus/@to)" />
                    </xsl:when>
                    <xsl:otherwise>

                        <xsl:choose>
                            <xsl:when test="//*:facsimile/*:surface">
                                <xsl:value-of select="//*:facsimile/*:surface[last()]/@n"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>cover</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>

                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <endPageLabel>
                <xsl:value-of select="$endPageLabel" />
            </endPageLabel>

            <endPagePosition>

                <xsl:choose>
                    <xsl:when test="//*:facsimile/*:surface">
                        <xsl:for-each select="//*:facsimile/*:surface" >
                            <xsl:if test="@n = $endPageLabel">
                                <xsl:value-of select="position()" />
                            </xsl:if>
                        </xsl:for-each>

                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>1</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>

            </endPagePosition>

            <xsl:if test="*:msContents/*:msItem">
                <children>
                    <xsl:apply-templates select="*:msContents/*:msItem" mode="logicalstructure" />
                </children>
            </xsl:if>

            <xsl:if test="*:msItem">
                <children>
                    <xsl:apply-templates select="*:msItem" mode="logicalstructure" />
                </children>
            </xsl:if>

        </logicalStructure>

    </xsl:template>



    <!-- ******************************HTML-->


    <xsl:template match="*:p" mode="html">

        <xsl:text>&lt;p&gt;</xsl:text>

        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;/p&gt;</xsl:text>

    </xsl:template>

    <!--allows creation of paragraphs in summary (a bit of a cheat - TEI doesn't allow p tags here so we use seg and process into p)-->
    <!--this is necessary to allow collapse to first paragraph in interface-->
    <xsl:template match="*:seg[@type='para']" mode="html">

        <xsl:text>&lt;p style=&apos;text-align: justify;&apos;&gt;</xsl:text>

        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/p&gt;</xsl:text>


    </xsl:template>

    <!--tables-->

    <xsl:template match="*:table" mode="html">

        <xsl:text>&lt;table border='1'&gt;</xsl:text>

        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;/table&gt;</xsl:text>

    </xsl:template>


    <xsl:template match="*:table/*:head" mode="html">

        <xsl:text>&lt;caption&gt;</xsl:text>

        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;/caption&gt;</xsl:text>

    </xsl:template>



    <xsl:template match="*:table/*:row" mode="html">

        <xsl:text>&lt;tr&gt;</xsl:text>

        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;/tr&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:table/*:row[@role='label']/*:cell" mode="html">

        <xsl:text>&lt;th&gt;</xsl:text>

        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;/th&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:table/*:row[@role='data']/*:cell" mode="html">

        <xsl:text>&lt;td&gt;</xsl:text>

        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;/td&gt;</xsl:text>

    </xsl:template>


    <!--end of tables-->


    <xsl:template match="*[not(local-name()='additions')]/*:list" mode="html">

        <xsl:text>&lt;div&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>
        <xsl:text>&lt;br /&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*[not(local-name()='additions')]/*:list/*:item" mode="html">


        <xsl:apply-templates mode="html"/>

        <xsl:text>&lt;br /&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:additions/*:list" mode="html">

        <xsl:apply-templates select="*:head" mode="html"/>

        <xsl:text>&lt;div style=&apos;list-style-type: disc;&apos;&gt;</xsl:text>
        <xsl:apply-templates select="*[not(local-name()='head')]" mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:additions/*:list/*:item" mode="html">

        <xsl:text>&lt;div style=&apos;display: list-item; margin-left: 20px;&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/div&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:lb" mode="html">

        <xsl:text>&lt;br /&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:title" mode="html">

        <xsl:text>&lt;i&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:term" mode="html">

        <xsl:text>&lt;i&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:q|*:quote" mode="html">

        <xsl:text>"</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>"</xsl:text>

    </xsl:template>

    <xsl:template match="*[@rend='italic']" mode="html">

        <xsl:text>&lt;i&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*[@rend='superscript']" mode="html">

        <xsl:text>&lt;sup&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/sup&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*[@rend='subscript']" mode="html">

        <xsl:text>&lt;sub&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/sub&gt;</xsl:text>

    </xsl:template>


    <xsl:template match="*[@rend='bold']" mode="html">

        <xsl:text>&lt;b&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/b&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:g" mode="html">

        <xsl:choose>
            <xsl:when test=".='%'">
                <xsl:text>&#x25CE;</xsl:text>
            </xsl:when>
            <xsl:when test=".='@'">
                <xsl:text>&#x2748;</xsl:text>
            </xsl:when>
            <xsl:when test=".='$'">
                <xsl:text>&#x2240;</xsl:text>
            </xsl:when>
            <xsl:when test=".='bhale'">
                <xsl:text>&#x2114;</xsl:text>
            </xsl:when>
            <xsl:when test=".='ba'">
                <xsl:text>&#x00A7;</xsl:text>
            </xsl:when>
            <xsl:when test=".='&#x00A7;'">
                <xsl:text>&#x30FB;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>&lt;i&gt;</xsl:text>
                <xsl:apply-templates mode="html"/>
                <xsl:text>&lt;/i&gt;</xsl:text>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*:l" mode="html">

        <xsl:if test="not(local-name(preceding-sibling::*[1]) = 'l')">
            <xsl:text>&lt;br /&gt;</xsl:text>
        </xsl:if>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;br /&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:name" mode="html">

        <xsl:choose>
            <xsl:when test="*[@type='display']">
                <xsl:value-of select="*[@type='display']"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="html"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*:ref[@type='biblio']" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>




    <xsl:template match="*:ref[@type='extant_mss']" mode="html">

        <xsl:choose>
            <xsl:when test="normalize-space(@target)">
                <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
                <xsl:value-of select="normalize-space(@target)"/>
                <xsl:text>&apos;&gt;</xsl:text>
                <xsl:apply-templates mode="html"/>
                <xsl:text>&lt;/a&gt;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="html"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*:ref[@type='cudl_link']" mode="html">

        <xsl:choose>
            <xsl:when test="normalize-space(@target)">
                <xsl:text>&lt;a href=&apos;</xsl:text>
                <xsl:value-of select="normalize-space(@target)"/>
                <xsl:text>&apos;&gt;</xsl:text>
                <xsl:apply-templates mode="html"/>
                <xsl:text>&lt;/a&gt;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="html"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*:ref[@type='nmm_link']" mode="html">

        <xsl:choose>
            <xsl:when test="normalize-space(@target)">
                <xsl:apply-templates mode="html"/>
                <xsl:text> [</xsl:text>
                <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
                <xsl:value-of select="normalize-space(@target)"/>
                <xsl:text>&apos;&gt;</xsl:text>
                <xsl:text>&lt;img title="Link to RMG" alt=&apos;RMG icon&apos; class=&apos;nmm_icon&apos; src=&apos;/images/general/nmm_small.png&apos;/&gt;</xsl:text>
                <xsl:text>&lt;/a&gt;</xsl:text>
                <xsl:text>]</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="html"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*:ref[not(@type)]" mode="html">

        <xsl:choose>
            <xsl:when test="normalize-space(@target)">

                <xsl:choose>

                    <xsl:when test="@rend='left' or @rend='right'">

                        <xsl:text>&lt;span style=&quot;float:</xsl:text>
                        <xsl:value-of select="@rend"/>
                        <xsl:text>; text-align:center; padding-bottom:10px&quot;&gt;</xsl:text>

                        <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
                        <xsl:value-of select="normalize-space(@target)"/>
                        <xsl:text>&apos;&gt;</xsl:text>
                        <xsl:apply-templates mode="html"/>
                        <xsl:text>&lt;/a&gt;</xsl:text>

                        <xsl:text>&lt;/span&gt;</xsl:text>

                    </xsl:when>

                    <xsl:otherwise>

                        <xsl:text>&lt;a target=&apos;_blank&apos; class=&apos;externalLink&apos; href=&apos;</xsl:text>
                        <xsl:value-of select="normalize-space(@target)"/>
                        <xsl:text>&apos;&gt;</xsl:text>
                        <xsl:apply-templates mode="html"/>
                        <xsl:text>&lt;/a&gt;</xsl:text>


                    </xsl:otherwise>


                </xsl:choose>

            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="html"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>


    <xsl:template match="*:ref[@type='popup']" mode="html">

        <xsl:choose>
            <xsl:when test="normalize-space(@target)">

                <xsl:choose>

                    <xsl:when test="@rend='left' or @rend='right'">

                        <xsl:text>&lt;span style=&quot;float:</xsl:text>
                        <xsl:value-of select="@rend"/>
                        <xsl:text>; text-align:center; padding-bottom:10px&quot;&gt;</xsl:text>

                        <xsl:text>&lt;a class=&apos;popup&apos; href=&apos;</xsl:text>
                        <xsl:value-of select="normalize-space(@target)"/>
                        <xsl:text>&apos;&gt;</xsl:text>
                        <xsl:apply-templates mode="html"/>
                        <xsl:text>&lt;/a&gt;</xsl:text>

                        <xsl:text>&lt;/span&gt;</xsl:text>

                    </xsl:when>

                    <xsl:otherwise>

                        <xsl:text>&lt;a class=&apos;popup&apos; href=&apos;</xsl:text>
                        <xsl:value-of select="normalize-space(@target)"/>
                        <xsl:text>&apos;&gt;</xsl:text>
                        <xsl:apply-templates mode="html"/>
                        <xsl:text>&lt;/a&gt;</xsl:text>


                    </xsl:otherwise>


                </xsl:choose>

            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="html"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>


    <xsl:template match="*:locus" mode="html">

        <xsl:variable name="from" select="normalize-space(@from)" />

        <xsl:variable name="page">

            <xsl:choose>
                <xsl:when test="//*:facsimile/*:surface">

                    <xsl:for-each select="//*:facsimile/*:surface" >
                        <xsl:if test="@n = $from">
                            <xsl:value-of select="position()" />
                        </xsl:if>
                    </xsl:for-each>


                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>1</xsl:text>
                </xsl:otherwise>
            </xsl:choose>

        </xsl:variable>

        <xsl:text>&lt;a href=&apos;&apos; onclick=&apos;store.loadPage(</xsl:text>
        <xsl:value-of select="$page" />
        <xsl:text>);return false;&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html" />
        <xsl:text>&lt;/a&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:graphic[not(@url)]" mode="html">

        <xsl:text>&lt;i class=&apos;graphic&apos; style=&apos;font-style:italic;&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>


    <xsl:template match="*:graphic[@url]" mode="html">


        <xsl:variable name="float">
            <xsl:choose>
                <xsl:when test="@rend='right'">
                    <xsl:text>float:right</xsl:text>

                </xsl:when>
                <xsl:when test="@rend='left'">
                    <xsl:text>float:left</xsl:text>

                </xsl:when>
                <xsl:otherwise> </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:text>&lt;img style=&quot;padding:10px;</xsl:text>
        <xsl:value-of select="$float"/>
        <xsl:text>&quot; src=&quot;</xsl:text>
        <xsl:value-of select="@url"/>
        <xsl:text>&quot; /&gt;</xsl:text>

    </xsl:template>


    <xsl:template match="*:damage" mode="html">

        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>[</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;damage&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
        <xsl:text> title=&apos;This text damaged in source&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>]</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:sic" mode="html">

        <xsl:text>&lt;i class=&apos;error&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
        <xsl:text> title=&apos;This text in error in source&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>(!)</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:term/*:sic" mode="html">

        <xsl:text>&lt;i class=&apos;error&apos;</xsl:text>
        <xsl:text> title=&apos;This text in error in source&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;color:red&apos;&gt;</xsl:text>
        <xsl:text>(!)</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:unclear" mode="html">

        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>[</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;unclear&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
        <xsl:text> title=&apos;This text imperfectly legible in source&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>]</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:supplied" mode="html">

        <xsl:text>&lt;i class=&apos;supplied&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
        <xsl:text> title=&apos;This text supplied by transcriber&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:add" mode="html">

        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>\</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;add&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
        <xsl:text> title=&apos;This text added&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>/</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:del[@type='illegible']" mode="html">

        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>&#x301A;</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;del&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
        <xsl:text> title=&apos;This text deleted and illegible&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>&#x301B;</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:del" mode="html">

        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>&#x301A;</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;del&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; text-decoration:line-through;&apos;</xsl:text>
        <xsl:text> title=&apos;This text deleted&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>&#x301B;</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:subst" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:gap" mode="html">

        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>&gt;-</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;gap&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:apply-templates mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>
        <xsl:text>&lt;i class=&apos;delim&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal; color:red&apos;&gt;</xsl:text>
        <xsl:text>-&lt;</xsl:text>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>

    <xsl:template match="*:desc" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <xsl:template match="*:choice[*:orig][*:reg[@type='hyphenated']]" mode="html">

        <xsl:text>&lt;i class=&apos;reg&apos;</xsl:text>
        <xsl:text> style=&apos;font-style:normal;&apos;</xsl:text>
        <xsl:text> title=&apos;String hyphenated for display. Original: </xsl:text>
        <xsl:value-of select="normalize-space(*:orig)"/>
        <xsl:text>&apos;&gt;</xsl:text>
        <xsl:apply-templates select="*:reg[@type='hyphenated']" mode="html"/>
        <xsl:text>&lt;/i&gt;</xsl:text>

    </xsl:template>




    <xsl:template match="*:reg" mode="html">

        <xsl:apply-templates mode="html"/>

    </xsl:template>

    <!-- <xsl:template match="*:reg[@type='hyphenated']" mode="html">

      <xsl:value-of select="replace(., '-', '')"/>

   </xsl:template>-->



    <xsl:template match="text()" mode="html">

        <xsl:variable name="translated" select="translate(., '^&#x00A7;', '&#x00A0;&#x30FB;')"/>
        <!--      <xsl:variable name="replaced" select="replace($translated, '&#x005F;&#x005F;&#x005F;', '&#x2014;&#x2014;&#x2014;')" /> -->
        <xsl:variable name="replaced"
                      select="replace($translated, '_ _ _', '&#x2014;&#x2014;&#x2014;')"/>
        <xsl:value-of select="$replaced"/>

    </xsl:template>


</xsl:stylesheet>
